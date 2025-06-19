output "cluster_sg_id" {
  description = "The ID of the security group created by the EKS cluster for node communication."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value = aws_eks_cluster.main.endpoint
}

output "cluster_ca" {
    description = "Certificate authority for the EKS cluster"
    value = aws_eks_cluster.main.certificate_authority[0].data
} 