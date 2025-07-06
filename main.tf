terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# EKS 클러스터 정보를 읽어옵니다. module.eks가 먼저 실행되도록 순서를 보장합니다.
data "aws_eks_cluster" "main" {
  depends_on = [module.eks]
  name       = var.cluster_name
}

# EKS 클러스터의 OIDC 인증서 지문(thumbprint)을 가져옵니다.
data "tls_certificate" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# EKS와 IAM을 연결해주는 IAM OIDC Provider를 직접 생성합니다.
resource "aws_iam_openid_connect_provider" "eks" {
  url             = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
}


# ===================================================================
# Modules: 각 인프라(VPC, EKS, S3, RDS)를 생성하는 부분입니다.
# ===================================================================

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

# ===================================================================
# "커스텀 금고" (Custom Secret) 생성:
# RDS가 관리하는 시크릿과 RDS 클러스터 정보를 조합하여,
# 애플리케이션이 필요로 하는 모든 정보를 담은 새로운 시크릿을 만듭니다.
# ===================================================================

# 1. RDS가 관리하는 시크릿에서 username과 password를 읽어옵니다.
data "aws_secretsmanager_secret_version" "rds_managed_secret" {
  # RDS 모듈이 출력하는, RDS가 관리하는 시크릿의 ARN을 참조합니다.
  secret_id = module.rds.db_credentials_secret_arn
}

# 2. 모든 접속 정보를 담을 우리만의 "커스텀 시크릿"을 생성합니다.
resource "aws_secretsmanager_secret" "custom_db_connection_details" {
  name_prefix = "custom-db-connection-details-"
  # 이 시크릿이 삭제될 때 즉시 삭제되도록 설정합니다. (복구 기간 없음)
  recovery_window_in_days = 0
}

# 3. 커스텀 시크릿에 실제 데이터(JSON)를 채워 넣습니다.
resource "aws_secretsmanager_secret_version" "custom_db_connection_details_version" {
  secret_id     = aws_secretsmanager_secret.custom_db_connection_details.id
  secret_string = jsonencode({
    # RDS가 관리하는 시크릿에서 읽어온 값
    username = jsondecode(data.aws_secretsmanager_secret_version.rds_managed_secret.secret_string)["username"]
    password = jsondecode(data.aws_secretsmanager_secret_version.rds_managed_secret.secret_string)["password"]
    # RDS 모듈이 출력하는 클러스터 정보
    host     = module.rds.cluster_endpoint
    port     = module.rds.cluster_port
    dbname   = module.rds.cluster_db_name
    engine   = "aurora-postgresql"
  })
}


# ===================================================================
# IRSA(IAM Roles for Service Accounts) for External Secrets Operator
# ===================================================================

# 1. IAM 정책(Policy) 생성: 위에서 만든 "커스텀 시크릿"만 읽도록 허용합니다.
resource "aws_iam_policy" "external_secrets_policy" {
  name        = "AllowESOReadCustomDBSecret"
  description = "Allows ESO to read the custom DB connection details secret"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "secretsmanager:GetSecretValue",
        # 이제 RDS 시크릿이 아닌, 우리가 만든 "커스텀 시크릿"의 ARN을 참조합니다.
        Resource = [aws_secretsmanager_secret.custom_db_connection_details.arn]
      }
    ]
  })
}

# 2. IAM 역할(Role) 생성: EKS의 'external-secrets-sa' 서비스 계정이 사용할 역할입니다.
resource "aws_iam_role" "external_secrets_role" {
  name = "external-secrets-role-tf"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:external-secrets:external-secrets-sa"
          }
        }
      }
    ]
  })
}

# 3. 정책과 역할 연결
resource "aws_iam_role_policy_attachment" "external_secrets_attach" {
  role       = aws_iam_role.external_secrets_role.name
  # 위에서 새로 정의한 정책을 연결합니다.
  policy_arn = aws_iam_policy.external_secrets_policy.arn
}

# ===================================================================
# Outputs: 최종 결과값입니다.
# ===================================================================

# external-secret.yaml에서 사용할 "커스텀 시크릿"의 ARN을 출력합니다.
output "custom_db_secret_arn" {
  description = "The ARN of the custom secret containing all DB connection details"
  value       = aws_secretsmanager_secret.custom_db_connection_details.arn
}

output "external_secrets_role_arn" {
  description = "The ARN of the IAM role for the External Secrets service account"
  value       = aws_iam_role.external_secrets_role.arn
} 