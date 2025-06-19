output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "private_db_subnet_ids" {
  description = "List of IDs of private DB subnets"
  value       = aws_subnet.private_db[*].id
}

output "nat_gateway_ips" {
  description = "List of public EIPs for the NAT Gateways"
  value       = aws_eip.nat[*].public_ip
} 