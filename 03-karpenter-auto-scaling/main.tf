terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
  }
  backend "s3" {
    bucket         = "eks-devopsproject-state-files-620958830769"
    key            = "karpenter/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-devopsproject-state-locking"
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = var.tags
  }
}

provider "helm" {
  kubernetes {
    host                   = local.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(local.eks_cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", local.eks_cluster_name, "--profile", "terraform"]
      command     = "aws"
    }
  }
}
