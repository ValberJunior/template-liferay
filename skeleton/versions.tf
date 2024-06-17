terraform {
  required_version = "~> 1.3"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.43.0"
    }
  }
}
