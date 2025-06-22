resource "aws_db_subnet_group" "aurora_pg" {
  name       = "aurora-pg-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = {
    Name = "Aurora PostgreSQL Subnet Group"
  }
}

resource "random_id" "secret_suffix" {
  byte_length = 4
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "aurora-pg-master-credentials-${random_id.secret_suffix.hex}"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.master_password.result
  })
}

resource "random_password" "master_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_rds_cluster" "aurora_pg" {
  cluster_identifier      = "aurora-pg-cluster"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "13.13"
  availability_zones      = var.availability_zones
  database_name           = "mypgdb"
  master_username         = jsondecode(aws_secretsmanager_secret_version.db_credentials.secret_string)["username"]
  master_password         = jsondecode(aws_secretsmanager_secret_version.db_credentials.secret_string)["password"]
  db_subnet_group_name    = aws_db_subnet_group.aurora_pg.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  skip_final_snapshot     = true
}

resource "aws_rds_cluster_instance" "aurora_pg" {
  count              = 2
  identifier         = "aurora-pg-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora_pg.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.aurora_pg.engine
  engine_version     = aws_rds_cluster.aurora_pg.engine_version
}

resource "aws_security_group" "db" {
  name        = "rds-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_cluster_sg_id] # This will be created in EKS module later
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
} 