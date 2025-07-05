terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# --- Data Sources to get EKS OIDC info for IRSA ---
data "aws_eks_cluster" "main" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# --- Modules ---
module "vpc" {
  source       = "./VPC"
  cluster_name = var.cluster_name
}

module "eks" {
  source             = "./EKS"
  private_subnet_ids = module.vpc.private_subnet_ids
  cluster_name       = var.cluster_name
}

module "s3" {
  source = "./S3"
}

module "rds" {
  source                = "./RDS"
  vpc_id                = module.vpc.vpc_id
  private_db_subnet_ids = module.vpc.private_db_subnet_ids
  eks_cluster_sg_id     = module.eks.cluster_sg_id
}

# --- IAM Resources for External Secrets Operator (IRSA) ---

# 1. IAM Policy that allows reading the specific RDS secret
resource "aws_iam_policy" "external_secrets_rds_policy" {
  name        = "AllowExternalSecretsReadRdsSecret"
  description = "Allows ESO to read the RDS master credentials"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "secretsmanager:GetSecretValue",
        # Dynamically reference the secret ARN from the RDS module's output
        Resource = ["${module.rds.db_credentials_secret_arn}*"]
      }
    ]
  })
}

# 2. IAM Role that the Kubernetes Service Account will assume
resource "aws_iam_role" "external_secrets_role" {
  name = "external-secrets-role-tf" # Naming it differently to avoid collision with potential old roles

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          # Trust the EKS OIDC provider
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # Condition: Only allow if the request comes from the 'external-secrets-sa' service account in the 'external-secrets' namespace
            "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:external-secrets:external-secrets-sa"
          }
        }
      }
    ]
  })
}

# 3. Attach the Policy to the Role
resource "aws_iam_role_policy_attachment" "external_secrets_rds_attach" {
  role       = aws_iam_role.external_secrets_role.name
  policy_arn = aws_iam_policy.external_secrets_rds_policy.arn
} 

# main.tf 맨 아래에 추가

output "db_credentials_secret_arn" {
  description = "The ARN of the master user credentials secret from the RDS module"
  value       = module.rds.db_credentials_secret_arn
}

output "external_secrets_role_arn" {
  description = "The ARN of the IAM role for the External Secrets service account"
  value       = aws_iam_role.external_secrets_role.arn
}