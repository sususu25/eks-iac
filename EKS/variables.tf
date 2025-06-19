variable "cluster_name" {
  description = "The name for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of IDs of private subnets for EKS node group"
  type        = list(string)
} 