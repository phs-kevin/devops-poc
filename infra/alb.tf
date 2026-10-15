# One ALB: port 80 serves production, port 8080 serves staging.
resource "aws_lb" "main" {
  name               = local.prefix
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

# Names must stay "devops-poc-<env>"; the deploy roles are scoped to that prefix.
resource "aws_lb_target_group" "app" {
  for_each             = local.envs
  name                 = "${local.prefix}-${each.key}"
  vpc_id               = aws_vpc.main.id
  port                 = 8000
  protocol             = "HTTP"
  target_type          = "instance"
  deregistration_delay = 15 # default 300s would make every host swap take 5 minutes

  health_check {
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "app" {
  for_each          = { production = 80, staging = 8080 }
  load_balancer_arn = aws_lb.main.arn
  port              = each.value
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[each.key].arn
  }
}
