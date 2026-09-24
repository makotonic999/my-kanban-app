# Amazon Managed Grafana (AMG)
# ローカル docker-compose の Grafana に相当。データソースとして AMP を参照する。

variable "enable_grafana" {
  description = "Amazon Managed Grafana ワークスペースを作成するか（AMG はユーザー単位課金）"
  type        = bool
  default     = true
}

# AMG が引き受けるサービスロール。
data "aws_iam_policy_document" "grafana_assume" {
  count = var.enable_grafana ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["grafana.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "grafana" {
  count              = var.enable_grafana ? 1 : 0
  name               = "${local.name}-grafana"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume[0].json
  tags               = { Name = "${local.name}-grafana" }
}

# Grafana が AMP をクエリするための権限（読み取り専用）。
data "aws_iam_policy_document" "grafana_amp_query" {
  count = var.enable_grafana ? 1 : 0

  statement {
    sid    = "QueryAmp"
    effect = "Allow"
    actions = [
      "aps:QueryMetrics",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
      "aps:ListWorkspaces",
      "aps:DescribeWorkspace",
    ]
    resources = ["*"] # 一部 List/Describe はリソース限定不可
  }
}

resource "aws_iam_role_policy" "grafana_amp_query" {
  count  = var.enable_grafana ? 1 : 0
  name   = "${local.name}-grafana-amp"
  role   = aws_iam_role.grafana[0].id
  policy = data.aws_iam_policy_document.grafana_amp_query[0].json
}

resource "aws_grafana_workspace" "main" {
  count = var.enable_grafana ? 1 : 0

  name                     = "${local.name}-grafana"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"] # IAM Identity Center(SSO) でログイン
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana[0].arn

  # Prometheus をデータソースとして有効化（AMP を追加）。
  data_sources = ["PROMETHEUS"]

  tags = { Name = "${local.name}-grafana" }
}

output "grafana_workspace_endpoint" {
  description = "Amazon Managed Grafana のエンドポイント"
  value       = var.enable_grafana ? aws_grafana_workspace.main[0].endpoint : null
}
