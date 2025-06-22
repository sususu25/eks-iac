terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
}

provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks-vpc-stack"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "eks-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "eks-rtb-public"
  }
}

resource "aws_subnet" "public" {
  count = 2
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index) # 10.1.0.0/20, 10.1.16.0/20
  availability_zone = ["ap-northeast-2a", "ap-northeast-2c"][count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "eks-subnet-public${count.index + 1}-ap-northeast-2${["a", "c"][count.index]}"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
    count = 2
    domain = "vpc"
    tags = {
        Name = "NAT-EIP-${count.index + 1}"
    }
}

resource "aws_nat_gateway" "main" {
    count = 2
    allocation_id = aws_eip.nat[count.index].id
    subnet_id     = aws_subnet.public[count.index].id

    tags = {
        Name = "NAT-GW-AZ2${["a", "c"][count.index]}"
    }

    depends_on = [aws_internet_gateway.main]
}

resource "aws_subnet" "private" {
  count = 2
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index + 2) # 10.1.32.0/20, 10.1.48.0/20
  availability_zone = ["ap-northeast-2a", "ap-northeast-2c"][count.index]

  tags = {
    Name = "eks-subnet-private${count.index + 1}-ap-northeast-2${["a", "c"][count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_route_table" "private" {
    count = 2
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.main[count.index].id
    }

    tags = {
        Name = "eks-rtb-private-2${["a", "c"][count.index]}"
    }
}

resource "aws_route_table" "private_db" {
  count  = 2
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "eks-rtb-private-db-2${["a", "c"][count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_subnet" "private_db" {
  count = 2
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index + 4) # 10.1.64.0/20, 10.1.80.0/20
  availability_zone = ["ap-northeast-2a", "ap-northeast-2c"][count.index]

  tags = {
    Name = "eks-subnet-privatedb${count.index + 1}-ap-northeast-2${["a", "c"][count.index]}"
  }
}

resource "aws_route_table_association" "private_db" {
  count          = 2
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[count.index].id
}

resource "aws_security_group" "vpc_endpoint" {
  name        = "vpc-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpc-endpoint-sg"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-northeast-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.private[0].id, aws_route_table.private[1].id]
  tags = {
    Name = "s3-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-2.ecr.api"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.vpc_endpoint.id
  ]
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  tags = {
    Name = "ecr-api-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-2.ecr.dkr"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.vpc_endpoint.id
  ]
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  tags = {
    Name = "ecr-dkr-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-2.sts"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.vpc_endpoint.id
  ]
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  tags = {
    Name = "sts-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-2.ec2"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.vpc_endpoint.id
  ]
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  tags = {
    Name = "ec2-vpc-endpoint"
  }
}