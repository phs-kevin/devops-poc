terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  # Local state for the PoC; *.tfstate is gitignored.
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { project = "devops-poc", managed_by = "terraform" }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  prefix     = "devops-poc"
  envs = {
    staging    = { gh_environment = "staging" }
    production = { gh_environment = "production" }
  }
}
