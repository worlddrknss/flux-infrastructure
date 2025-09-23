terraform {
  backend "s3" {
    encrypt    = true
    use_lockfile = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

# -------------------------
# VPC + Subnets
# -------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.2"

  name = "${var.cluster_name}-vpc"
  cidr = "10.123.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.123.0.0/24", "10.123.1.0/24", "10.123.2.0/24"]
  public_subnets  = ["10.123.64.0/18", "10.123.128.0/18", "10.123.192.0/18"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# -------------------------
# GuardDuty VPC Endpoint
# -------------------------
module "endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.2"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = []

  endpoints = {
    guardduty = {
      service             = "guardduty-data"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      tags                = { Name = "${var.cluster_name}-guardduty-endpoint" }
    }
  }
}

# -------------------------
# EKS Cluster
# -------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.33"

  # EKS Cluster Addons
  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  # Cluster networking
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # IAM OIDC provider for IRSA
  enable_irsa                              = true
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  # Endpoint access configuration
  endpoint_public_access = true
  endpoint_private_access = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Node Groups
  eks_managed_node_groups = {
    default = {
      desired_size   = 3
      max_size       = 3
      min_size       = 1
      instance_types = ["t3.xlarge"]
      capacity_type  = "ON_DEMAND"

      # AMI configuration
      ami_type             = "AL2023_x86_64_STANDARD"
      release_version      = null

      # Update to latest AMI version on every apply
      force_update_version = true

      # Node group networking
      subnet_ids = module.vpc.private_subnets
    }
  }
}