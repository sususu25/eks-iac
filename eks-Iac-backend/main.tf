# 이 코드는 백엔드용 S3 버킷과 DynamoDB 테이블을 생성하기 위한 것입니다.
# 이 파일은 'eks-Iac-backend' 라는 별도의 디렉토리에서 실행됩니다.

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

# 1. 상태 파일을 저장할 S3 버킷
resource "aws_s3_bucket" "terraform_state" {
  bucket = "tfstate-eks-iac-20240730" #  !!중요!! 전 세계에서 유일한 이름으로 변경해야 할 수 있습니다.

  lifecycle {
    prevent_destroy = true
  }
}

# 2. S3 버킷의 버전 관리 기능 활성화
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 3. S3 버킷의 서버 측 암호화 설정
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. 상태 잠금을 위한 DynamoDB 테이블
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "eks-iac-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
} 