variable "cluster_name" {
  description = "The name for the EKS cluster"
  type        = string
  default     = "main-cluster"
}

variable "availability_zones" {
  description = "The availability zones to use for the VPC and database instances"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
} 