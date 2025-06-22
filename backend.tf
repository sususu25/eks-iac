# S3 백엔드 구성: Terraform 상태 파일을 원격 S3 버킷에 저장합니다.
terraform {
  backend "s3" {
    bucket         = "tfstate-eks-iac-20240730"
    key            = "eks-iac/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "eks-iac-tf-locks"
    encrypt        = true
  }
} 