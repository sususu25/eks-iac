resource "aws_iam_role" "cluster" {
  name = "eks-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster-AmazonEKSVPCResourceController,
  ]

  tags = {
    Environment = "Testing"
  }

  timeouts {
    create = "60m"
    delete = "60m"
  }
}

resource "aws_iam_role" "nodegroup" {
  name = "eks-nodegroup-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "nodegroup-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodegroup.name
}

resource "aws_iam_role_policy_attachment" "nodegroup-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodegroup.name
}

resource "aws_iam_role_policy_attachment" "nodegroup-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodegroup.name
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodegroup"
  node_role_arn   = aws_iam_role.nodegroup.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["t3.small"]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 2
  }
  
  remote_access {
    ec2_ssh_key = "prod-connect"
  }

  disk_size = 20
  
  depends_on = [
    aws_iam_role_policy_attachment.nodegroup-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodegroup-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.nodegroup-AmazonEKS_CNI_Policy,
  ]

  tags = {
    Name = "main-nodegroup"
  }
} 