resource "aws_ecr_repository" "app" {
  name                 = "${local.name}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # 学習用途: destroy 時にイメージごと削除できるように

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${local.name}-api" }
}

# 直近 10 イメージのみ保持し、古いものは自動削除（ストレージ費の抑制）。
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
