# GitHub Actions logs in with short-lived OIDC tokens; no AWS keys in GitHub.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Each role trusts only jobs that run in the matching GitHub environment.
data "aws_iam_policy_document" "deploy_trust" {
  for_each = local.envs
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${var.github_sub_prefix}:environment:${each.value.gh_environment}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  for_each             = local.envs
  name                 = "${local.prefix}-${each.key}-deploy"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust[each.key].json
  max_session_duration = 3600
}

# Shared by both roles: run the deploy script on this env's hosts and swap them
# in and out of this env's target group. Instances and target groups are created
# later and must carry the env tag / name prefix used here.
data "aws_iam_policy_document" "deploy_common" {
  for_each = local.envs

  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid       = "SsmSendToEnvHosts"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:${var.region}:${local.account_id}:instance/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/env"
      values   = [each.key]
    }
  }
  statement {
    sid       = "SsmRunShellScriptOnly"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ssm:${var.region}::document/AWS-RunShellScript"]
  }
  statement {
    sid       = "SsmReadResults"
    actions   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"]
    resources = ["*"]
  }
  statement {
    sid       = "SwapTargets"
    actions   = ["elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets"]
    resources = ["arn:aws:elasticloadbalancing:${var.region}:${local.account_id}:targetgroup/${local.prefix}-${each.key}/*"]
  }
  statement {
    sid       = "ReadTargetHealth"
    actions   = ["elasticloadbalancing:DescribeTargetHealth"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy_common" {
  for_each = local.envs
  name     = "deploy"
  role     = aws_iam_role.deploy[each.key].id
  policy   = data.aws_iam_policy_document.deploy_common[each.key].json
}

# Staging builds and pushes new images.
data "aws_iam_policy_document" "staging_push" {
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:DescribeImages",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "staging_push" {
  name   = "ecr-push"
  role   = aws_iam_role.deploy["staging"].id
  policy = data.aws_iam_policy_document.staging_push.json
}

# Production never uploads layers; it can only add a version tag to an image
# staging already pushed (BatchGetImage + PutImage of the same manifest).
data "aws_iam_policy_document" "prod_promote" {
  statement {
    actions   = ["ecr:BatchGetImage", "ecr:PutImage", "ecr:DescribeImages"]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "prod_promote" {
  name   = "ecr-promote"
  role   = aws_iam_role.deploy["production"].id
  policy = data.aws_iam_policy_document.prod_promote.json
}
