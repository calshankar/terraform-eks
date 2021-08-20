#####
# Backend and provider config
#####
terraform {
  required_version = ">= 1.0.0"

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "<TF cloud organization"

    workspaces {
      name = "<TF-cloud-workspace-name>"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.52"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.1"
    }
  }
}

provider "aws" {
  assume_role {
    role_arn     = var.aws_role_arn
    session_name = "EKS_deployment_session_${var.tags["Environment"]}"
  }

  region = var.region
}
