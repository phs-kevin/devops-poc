resource "aws_ecr_repository" "app" {
  name                 = "${local.prefix}/shn-site"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # PoC only, so destroy works with images present

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images"
      selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }
      action       = { type = "expire" }
    }]
  })
}
