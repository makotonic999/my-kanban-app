resource "aws_ecs_cluster" "main" {
  name = "${local.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${local.name}-cluster" }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}-api"
  retention_in_days = 14
  tags              = { Name = "${local.name}-api-logs" }
}

resource "aws_cloudwatch_log_group" "adot" {
  name              = "/ecs/${local.name}-adot"
  retention_in_days = 14
  tags              = { Name = "${local.name}-adot-logs" }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.app_cpu
  memory                   = var.app_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  # ARM(Graviton) は Fargate でも安いが、イメージのアーキに合わせる必要がある。
  # 既存 Dockerfile は amd64 前提のため X86_64 を指定。
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${aws_ecr_repository.app.repository_url}:${var.app_image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.app_container_port
          protocol      = "tcp"
        }
      ]

      # 機密は環境変数直書きせず、SSM から実行時に注入する。
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = aws_ssm_parameter.database_url.arn
        },
        {
          name      = "JWT_SECRET"
          valueFrom = aws_ssm_parameter.jwt_secret.arn
        }
      ]

      environment = [
        {
          name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
          value = "" # オブザーバビリティ基盤は後続フェーズで接続
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "api"
        }
      }
    },
    {
      # ADOT Collector sidecar: /metrics をスクレイプし AMP へ remote_write する。
      name      = "adot-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      essential = false

      # 設定は SSM から AOT_CONFIG_CONTENT で注入。
      secrets = [
        {
          name      = "AOT_CONFIG_CONTENT"
          valueFrom = aws_ssm_parameter.adot_config.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.adot.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "adot"
        }
      }
    }
  ])

  tags = { Name = "${local.name}-api" }
}

resource "aws_ecs_service" "app" {
  name            = "${local.name}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.ecs_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = local.ecs_assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "api"
    container_port   = var.app_container_port
  }

  # ALB のリスナーが出来てからサービスを起動する。
  depends_on = [aws_lb_listener.http]

  # デプロイのたびに tag=latest を再pullさせたい場合に有効。
  lifecycle {
    ignore_changes = [task_definition] # CI/CD で更新する想定のため drift を無視
  }

  tags = { Name = "${local.name}-api" }
}
