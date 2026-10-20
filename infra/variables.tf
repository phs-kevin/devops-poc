variable "region" {
  type    = string
  default = "us-east-2"
}

# A dedicated CLI profile keeps Terraform off whatever the default login is.
variable "aws_profile" {
  type    = string
  default = "devops-poc"
}

# Set in terraform.tfvars.
variable "aws_account_id" {
  type = string
}

# The repo uses GitHub's immutable OIDC subject (owner and repo IDs included), so a
# renamed or re-created repo with the same name can't assume the deploy roles.
# Check with: gh api repos/<owner>/<repo>/actions/oidc/customization/sub
variable "github_sub_prefix" {
  type    = string
  default = "repo:phs-kevin@327092258/devops-poc@1405968493"
}

# Who can reach the ALB. Deploys go through SSM, so only people browsing the
# app need to be listed here.
variable "allowed_cidrs" {
  type = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# Set to 2+ to test a rolling deploy that stops at the first failed host.
variable "production_instance_count" {
  type    = number
  default = 1
}
