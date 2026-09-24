output "alb_dns_name" {
  description = "アプリのエンドポイント（ALB の DNS 名）"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "docker push 先の ECR リポジトリURL"
  value       = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  description = "RDS のエンドポイント（VPC 内からのみ到達可能）"
  value       = aws_db_instance.main.address
}

output "ecs_cluster_name" {
  description = "ECS クラスタ名"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS サービス名"
  value       = aws_ecs_service.app.name
}

output "nat_gateway_enabled" {
  description = "NAT Gateway を作成したか（コスト影響大）"
  value       = var.enable_nat_gateway
}
