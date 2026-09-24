# Amazon Managed Service for Prometheus (AMP)
# ローカル docker-compose の Prometheus に相当。既存の SLO/alert ルール資産を流用する。

resource "aws_prometheus_workspace" "main" {
  alias = "${local.name}-amp"

  tags = { Name = "${local.name}-amp" }
}

# SLO recording rules と alert rules を単一ネームスペースに登録。
# 内容はローカルの slo_rules.yml / alert_rules.yml と同一（AMP 形式に結合したもの）。
resource "aws_prometheus_rule_group_namespace" "slo" {
  name         = "${local.name}-slo"
  workspace_id = aws_prometheus_workspace.main.id
  data         = file("${path.module}/amp_rules.yml")
}

# AMP のクエリ/取り込みエンドポイントを SSM に保存（ADOT sidecar / 参照用）。
resource "aws_ssm_parameter" "amp_remote_write_url" {
  name  = "/${local.name}/amp/remote_write_url"
  type  = "String"
  value = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
  tags  = { Name = "${local.name}-amp-remote-write" }
}

output "amp_workspace_id" {
  description = "AMP ワークスペース ID"
  value       = aws_prometheus_workspace.main.id
}

output "amp_prometheus_endpoint" {
  description = "AMP のエンドポイント（Grafana データソース / remote_write に使用）"
  value       = aws_prometheus_workspace.main.prometheus_endpoint
}
