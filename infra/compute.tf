locals {
  instances = merge(
    { "staging-1" = "staging" },
    { for i in range(var.production_instance_count) : "production-${i + 1}" => "production" },
  )
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  for_each           = local.envs
  name               = "${local.prefix}-${each.key}-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "instance_ssm" {
  for_each   = local.envs
  role       = aws_iam_role.instance[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Hosts pull images and read only their own environment's secret.
data "aws_iam_policy_document" "instance" {
  for_each = local.envs
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
    resources = [aws_ecr_repository.app.arn]
  }
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.app[each.key].arn]
  }
}

resource "aws_iam_role_policy" "instance" {
  for_each = local.envs
  name     = "app"
  role     = aws_iam_role.instance[each.key].id
  policy   = data.aws_iam_policy_document.instance[each.key].json
}

resource "aws_iam_instance_profile" "instance" {
  for_each = local.envs
  name     = "${local.prefix}-${each.key}-instance"
  role     = aws_iam_role.instance[each.key].name
}

resource "aws_instance" "app" {
  for_each               = local.instances
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[index(keys(local.instances), each.key) % 2].id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.instance[each.value].name

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    run_sh    = file("${path.module}/../deploy/run.sh")
    region    = var.region
    registry  = split("/", aws_ecr_repository.app.repository_url)[0]
    repo      = aws_ecr_repository.app.name
    secret_id = aws_secretsmanager_secret.app[each.value].name
  })
  user_data_replace_on_change = true # a run.sh change rebuilds the host

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2          # lets the container reach the instance role
  }

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  # `env` must match the deploy roles' SSM condition.
  tags = { Name = "${local.prefix}-${each.key}", env = each.value }

  lifecycle {
    ignore_changes = [ami] # don't rebuild hosts every time AWS publishes a new AMI
  }
}

resource "aws_lb_target_group_attachment" "app" {
  for_each         = local.instances
  target_group_arn = aws_lb_target_group.app[each.value].arn
  target_id        = aws_instance.app[each.key].id
}
