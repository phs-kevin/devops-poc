output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "deploy_role_arns" {
  value = { for k, r in aws_iam_role.deploy : k => r.arn }
}

output "secret_ids" {
  value = { for k, s in aws_secretsmanager_secret.app : k => s.name }
}

output "urls" {
  value = {
    production = "http://${aws_lb.main.dns_name}"
    staging    = "http://${aws_lb.main.dns_name}:8080"
  }
}

output "instance_ids" {
  value = { for env in keys(local.envs) : env => join(" ", [for k, e in local.instances : aws_instance.app[k].id if e == env]) }
}

output "target_group_arns" {
  value = { for k, tg in aws_lb_target_group.app : k => tg.arn }
}
