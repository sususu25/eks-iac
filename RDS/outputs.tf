    output "db_credentials_secret_arn" {
      description = "The ARN of the master user credentials secret managed by RDS"
      # 리소스 참조 경로가 바뀝니다.
      value       = aws_rds_cluster.aurora_pg.master_user_secret[0].secret_arn
    }