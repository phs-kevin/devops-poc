output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "deploy_role_arns" {
  value = { for k, r in aws_iam_role.deploy : k => r.arn }
}

output "secret_ids" {
  value = { for k, s in aws_secretsmanager_secret.app : k => s.name }
}
