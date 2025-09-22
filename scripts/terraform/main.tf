terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
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
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# -------------------------
# EKS Cluster
# -------------------------
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name = var.cluster_name
  kubernetes_version = "1.31"

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true
  authentication_mode = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      desired_size = 3
      max_size = 3
      min_size = 1
      instance_types = ["t3.large"]
      capacity_type = "ON_DEMAND"
    }
  }
}
