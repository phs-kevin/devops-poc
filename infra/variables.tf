variable "region" {
  type    = string
  default = "us-east-2"
}

# The repo uses GitHub's immutable OIDC subject (owner and repo IDs included), so a
# renamed or re-created repo with the same name can't assume the deploy roles.
# Check with: gh api repos/<owner>/<repo>/actions/oidc/customization/sub
variable "github_sub_prefix" {
  type    = string
  default = "repo:phs-kevin@327092258/devops-poc@1405968493"
}
