# App secrets, one per environment. Values are dummies for the PoC; rotate them
# with put-secret-value (Terraform ignores later changes).
resource "aws_secretsmanager_secret" "app" {
  for_each                = local.envs
  name                    = "${local.prefix}/${each.key}/app"
  recovery_window_in_days = 0 # allow immediate re-create while experimenting
}

resource "aws_secretsmanager_secret_version" "app" {
  for_each  = local.envs
  secret_id = aws_secretsmanager_secret.app[each.key].id
  secret_string = jsonencode({
    SECRET_KEY  = "${each.key}-dummy-secret-key"
    DB_PASSWORD = "${each.key}-dummy-db-password"
    API_TOKEN   = "${each.key}-dummy-api-token"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
