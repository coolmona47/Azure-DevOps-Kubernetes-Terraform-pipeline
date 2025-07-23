# aws --version
# aws eks --region us-east-1 update-kubeconfig --name in28minutes-cluster
# Uses default VPC and Subnet. Create Your Own VPC and Private Subnets for Prod Usage.
# terraform-backend-state-mohan-123 ( aws bucket name)
#AKIAU6WUUWY4EADDW36G

terraform {
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "us-east-1"
  }
  
  # Move version constraints here (fixes the warning)
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.12"
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
  version = "12.2.0"  # Use version that supports your original syntax
  
  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.18"  # Compatible version for module 12.x
  
  # CORRECT: Use 'subnets' for version 12.x
  subnets = ["subnet-035bd89faaa4b160b", "subnet-0397545b2caac2cb1"] #CHANGE
  vpc_id  = aws_default_vpc.default.id
  #vpc_id = "vpc-1234556abcdef"
  
  # CORRECT: Node group configuration for v12.x (your original format)
  node_groups = {
    main = {
      instance_type    = "t3.medium"  # t2.micro may have issues
      asg_max_size     = 5
      asg_desired_capacity = 3
      asg_min_size     = 3
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.in28minutes-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.in28minutes-cluster.cluster_id
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