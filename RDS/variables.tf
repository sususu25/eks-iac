variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "private_db_subnet_ids" {
  description = "List of IDs of private DB subnets for RDS"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones for RDS cluster"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "eks_cluster_sg_id" {
  description = "The security group ID of the EKS cluster to allow DB access"
  type        = string
} 