variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "private_db_subnet_ids" {
  description = "List of IDs of private DB subnets for DocumentDB"
  type        = list(string)
}

variable "eks_cluster_sg_id" {
  description = "The security group ID of the EKS cluster to allow DB access"
  type        = string
} 