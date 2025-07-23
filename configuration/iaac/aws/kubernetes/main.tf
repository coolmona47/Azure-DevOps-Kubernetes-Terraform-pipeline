# aws --version
# aws eks --region us-east-1 update-kubeconfig --name in28minutes-cluster
# Uses default VPC and Subnet. Create Your Own VPC and Private Subnets for Prod Usage.
# terraform-backend-state-mohan-123 ( aws bucket name)
#AKIAU6WUUWY4EADDW36G

terraform {
  backend "s3" {
    bucket = "my_bucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "us-east-1"
  }
  
  # Move version constraints here (fixes the warning)
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.12"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_default_vpc" "default" {
}

# Remove version from provider block
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

module "in28minutes-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.31.2"  # Compatible with Terraform 1.5.7
  
  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.24"  # Supported version
  
  # CORRECT: Use 'subnet_ids' for version 18.x
  vpc_id     = aws_default_vpc.default.id
  subnet_ids = ["subnet-035bd89faaa4b160b", "subnet-0397545b2caac2cb1"] #CHANGE
  
  # CORRECT: EKS managed node groups for v18.x
  eks_managed_node_groups = {
    main = {
      instance_types = ["t3.medium"]
      min_size       = 3
      max_size       = 5
      desired_size   = 3
      
      # Additional required settings for v18.x
      ami_type       = "AL2_x86_64"
      capacity_type  = "ON_DEMAND"
    }
  }
  
  # Required for v18.x
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
}

data "aws_eks_cluster" "cluster" {
  name = module.in28minutes-cluster.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.in28minutes-cluster.cluster_name
}

# We will use ServiceAccount to connect to K8S Cluster in CI/CD mode
# ServiceAccount needs permissions to create deployments 
# and services in default namespace
resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}

# Needed to set the default region
provider "aws" {
  region = "us-east-1"
}