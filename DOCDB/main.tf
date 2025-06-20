resource "aws_docdb_subnet_group" "main" {
  name       = "docdb-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = {
    Name = "DocumentDB Subnet Group"
  }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "docdb-master-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "docdbadmin"
    password = random_password.master_password.result
  })
}

resource "random_password" "master_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier      = "docdb-cluster"
  engine                  = "docdb"
  engine_version          = "5.0.0"
  master_username         = jsondecode(aws_secretsmanager_secret_version.db_credentials.secret_string)["username"]
  master_password         = jsondecode(aws_secretsmanager_secret_version.db_credentials.secret_string)["password"]
  db_subnet_group_name    = aws_docdb_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  skip_final_snapshot     = true
}

resource "aws_docdb_cluster_instance" "main" {
  count              = 2
  identifier         = "docdb-instance-${count.index}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = "db.r5.large"
}

resource "aws_security_group" "db" {
  name        = "docdb-sg"
  description = "Security group for DocumentDB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 27017 # MongoDB port
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [var.eks_cluster_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
} 