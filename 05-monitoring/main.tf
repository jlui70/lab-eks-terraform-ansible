terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "eks-devopsproject-state-files-620958830769"
    key            = "monitoring/terraform.tfstate"
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