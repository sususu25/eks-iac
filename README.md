# Fowarding-Assist-App 인프라스트럭처 (IaC)

이 프로젝트는 "Fowarding-Assist-App" 애플리케이션 스택 배포를 위한 AWS 인프라를 Terraform을 사용하여 코드로 관리(IaC)합니다.

## 🚀 프로젝트 목표

- **자동화된 인프라:** VPC, EKS, RDS 등 애플리케이션 구동에 필요한 모든 기반 인프라를 코드를 통해 자동으로 프로비저닝합니다.
- **재현성 및 일관성:** 누가, 언제 실행하더라도 항상 동일한 구성의 인프라를 생성하여 "내 컴퓨터에선 됐는데..."와 같은 문제를 방지합니다.
- **모듈화를 통한 관리 용이성:** 각 기능 단위(VPC, EKS 등)를 모듈로 분리하여 코드의 가독성을 높이고 유지보수를 용이하게 합니다.

---

## 🏗️ 아키텍처 구조

이 Terraform 프로젝트는 다음과 같은 모듈식 구조로 구성되어 있습니다.

- **Root (`main.tf`, `variables.tf`, `backend.tf`)**:
  - 전체 모듈을 총괄하고, 각 모듈에 필요한 변수를 전달합니다.
  - S3를 원격 백엔드로 사용하여 팀원 간의 상태를 공유하고, DynamoDB로 상태 잠금(Lock)을 관리합니다.

- **VPC 모듈 (`./VPC`)**:
  - 애플리케이션의 기반이 되는 가상 네트워크(VPC)를 생성합니다.
  - **리소스:** `aws_vpc`, `aws_subnet` (Public, Private, Private DB용), `aws_internet_gateway`, `aws_nat_gateway`, `aws_route_table` 등.
  - **특징:** EKS와 데이터베이스를 위한 서브넷을 논리적으로 분리하고, DB 서브넷은 인터넷 아웃바운드 경로가 없는 독립된 라우팅 테이블을 사용하여 보안을 강화했습니다.

- **EKS 모듈 (`./EKS`)**:
  - 컨테이너화된 애플리케이션을 실행하기 위한 Kubernetes 클러스터(EKS)를 생성합니다.
  - **리소스:** `aws_eks_cluster`, `aws_eks_node_group`, IAM 역할 및 정책 등.

- **RDS 모듈 (`./RDS`)**:
  - 관리형 관계형 데이터베이스(PostgreSQL) 클러스터를 생성합니다.
  - **리소스:** `aws_rds_cluster`, `aws_rds_cluster_instance`, `aws_db_subnet_group`, `aws_security_group`.
  - **특징:** 마스터 암호는 `aws_secretsmanager_secret`을 통해 안전하게 관리되며, 암호 이름은 `random_id`를 통해 재생성 시에도 충돌이 발생하지 않도록 고유하게 생성됩니다.

- **S3 모듈 (`./S3`)**:
  - 애플리케이션에서 사용할 파일 스토리지(S3 버킷)를 생성합니다.
  - **리소스:** `aws_s3_bucket`.

---

## 🛠️ 사용법

### 사전 준비

- AWS 계정과 로컬에 설정된 AWS 자격 증명 (Access Key)
- Terraform CLI (v1.x 이상) 설치

### 배포 및 변경

1.  **프로젝트 초기화:**
    `eks-Iac` 루트 디렉토리에서 아래 명령을 실행하여 필요한 프로바이더와 모듈을 다운로드하고, 원격 백엔드 설정을 초기화합니다.
    ```bash
    terraform init
    ```

2.  **실행 계획 검토:**
    코드를 변경한 후, 어떤 리소스가 생성/수정/삭제될지 미리 확인합니다.
    ```bash
    terraform plan
    ```

3.  **인프라 배포:**
    계획이 예상대로 나왔다면, 실제 인프라에 적용합니다.
    ```bash
    terraform apply
    ```

### 인프라 삭제

- **주의:** 이 명령은 생성된 모든 AWS 리소스를 삭제하므로, 운영 환경에서는 절대 사용해서는 안 됩니다.
```bash
terraform destroy
```

---

## 💡 개선 제안

- **환경별 변수 분리:** `dev`, `staging`, `prod` 등 환경에 따라 다른 변수 값을 적용할 수 있도록 `*.tfvars` 파일을 사용하여 구성을 분리합니다.
- **CI/CD 파이프라인 연동:** Git push 시 자동으로 `terraform plan`을 실행하여 변경 사항을 검토하고, main 브랜치에 merge 시 `apply`까지 자동화하는 파이프라인을 구축합니다.
- **모니터링 및 로깅 강화:** CloudWatch, Prometheus, Grafana 등을 연동하여 시스템의 상태를 실시간으로 모니터링하고 로그를 중앙에서 관리하는 체계를 구축합니다.

---

# Fowarding-Assist-App Infrastructure (IaC) - English Version

This project manages the AWS infrastructure for deploying the "Fowarding-Assist-App" application stack as Infrastructure as Code (IaC) using Terraform.

## 🚀 Project Objectives

- **Automated Infrastructure:** Automatically provision all necessary base infrastructure, including VPC, EKS, and RDS, through code.
- **Reproducibility and Consistency:** Ensure that the same infrastructure configuration is created every time, regardless of who runs it or when, preventing "it worked on my machine" issues.
- **Ease of Management through Modularization:** Increase code readability and simplify maintenance by separating each functional unit (VPC, EKS, etc.) into modules.

---

## 🏗️ Architecture

This Terraform project is structured modularly as follows:

- **Root (`main.tf`, `variables.tf`, `backend.tf`)**:
  - Orchestrates all modules and passes the necessary variables to each.
  - Uses an S3 remote backend to share state among team members and manages state locking with DynamoDB.

- **VPC Module (`./VPC`)**:
  - Creates the virtual network (VPC) that forms the foundation of the application.
  - **Resources:** `aws_vpc`, `aws_subnet` (for Public, Private, and Private DB), `aws_internet_gateway`, `aws_nat_gateway`, `aws_route_table`, etc.
  - **Features:** Logically separates subnets for EKS and databases. The DB subnets use an isolated route table with no outbound internet access to enhance security.

- **EKS Module (`./EKS`)**:
  - Creates a Kubernetes cluster (EKS) to run containerized applications.
  - **Resources:** `aws_eks_cluster`, `aws_eks_node_group`, IAM roles and policies, etc.

- **RDS Module (`./RDS`)**:
  - Creates a managed relational database (PostgreSQL) cluster.
  - **Resources:** `aws_rds_cluster`, `aws_rds_cluster_instance`, `aws_db_subnet_group`, `aws_security_group`.
  - **Features:** The master password is securely managed via `aws_secretsmanager_secret`, and its name is uniquely generated using `random_id` to prevent conflicts during re-creation.

- **S3 Module (`./S3`)**:
  - Creates an S3 bucket for file storage used by the application.
  - **Resources:** `aws_s3_bucket`.

---

## 🛠️ Usage

### Prerequisites

- An AWS account and locally configured AWS credentials (Access Key).
- Terraform CLI (v1.x or later) installed.

### Deployment and Modifications

1.  **Initialize Project:**
    From the `eks-Iac` root directory, run the command below to download necessary providers and modules, and to initialize the remote backend configuration.
    ```bash
    terraform init
    ```

2.  **Review Execution Plan:**
    After making code changes, preview which resources will be created, modified, or deleted.
    ```bash
    terraform plan
    ```

3.  **Deploy Infrastructure:**
    If the plan looks correct, apply it to your actual infrastructure.
    ```bash
    terraform apply
    ```

### Destroy Infrastructure

- **Caution:** This command will delete all created AWS resources and should never be used in a production environment.
```bash
terraform destroy
```

---

## 💡 Recommended Improvements

- **Environment-Specific Variables:** Separate configurations for different environments like `dev`, `staging`, and `prod` by using `*.tfvars` files to apply different variable values.
- **CI/CD Pipeline Integration:** Build a pipeline that automatically runs `terraform plan` on a git push to review changes and automates `apply` upon merging to the main branch.
- **Enhanced Monitoring and Logging:** Establish a system for real-time system monitoring and centralized log management by integrating services like CloudWatch, Prometheus, and Grafana. 