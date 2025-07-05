resource "aws_db_subnet_group" "aurora_pg" {
  name       = "aurora-pg-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = {
    Name = "Aurora PostgreSQL Subnet Group"
  }
}

resource "aws_rds_cluster" "aurora_pg" {
  cluster_identifier          = "aurora-pg-cluster"
  engine                      = "aurora-postgresql"
  engine_mode                 = "provisioned"
  engine_version              = "13.13"
  availability_zones          = var.availability_zones
  database_name               = "mypgdb"
  master_username             = "dbadmin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.aurora_pg.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  skip_final_snapshot         = true
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