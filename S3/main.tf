terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_s3_bucket" "output_bucket" {
  bucket = "doc-generator-output"

  tags = {
    Name        = "Document Generator Output"
    Environment = "Testing"
  }
} 