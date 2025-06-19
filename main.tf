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

module "vpc" {
  source       = "./VPC"
  cluster_name = var.cluster_name
}

module "eks" {
  source             = "./EKS"
  vpc_id             = module.vpc.vpc_id
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

module "docdb" {
  source                = "./DOCDB"
  vpc_id                = module.vpc.vpc_id
  private_db_subnet_ids = module.vpc.private_db_subnet_ids
  eks_cluster_sg_id     = module.eks.cluster_sg_id
} 