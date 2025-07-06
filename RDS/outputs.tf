    output "db_credentials_secret_arn" {
      description = "The ARN of the master user credentials secret managed by RDS"
      # 리소스 참조 경로가 바뀝니다.
      value       = aws_rds_cluster.aurora_pg.master_user_secret[0].secret_arn
    }

    # RDS/outputs.tf

output "cluster_endpoint" {
  description = "The endpoint of the RDS cluster"
  value       = aws_rds_cluster.aurora_pg.endpoint
}

output "cluster_port" {
  description = "The port of the RDS cluster"
  value       = aws_rds_cluster.aurora_pg.port
}

output "cluster_db_name" {
  description = "The database name of the RDS cluster"
  value       = aws_rds_cluster.aurora_pg.database_name
}