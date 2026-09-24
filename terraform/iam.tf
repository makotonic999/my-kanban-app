data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---- タスク実行ロール: イメージpull・ログ出力・シークレット取得に使用 ----
resource "aws_iam_role" "ecs_execution" {
  name               = "${local.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = { Name = "${local.name}-ecs-execution" }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# SSM Parameter Store のシークレット読み取り + KMS 復号を最小権限で付与。
data "aws_iam_policy_document" "ecs_secrets" {
  statement {
    sid    = "ReadSsmParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]
    resources = [
      aws_ssm_parameter.database_url.arn,
      aws_ssm_parameter.jwt_secret.arn,
      aws_ssm_parameter.adot_config.arn,
    ]
  }
  statement {
    sid       = "DecryptSsm"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"] # SSM 既定キー。厳密化するなら CMK を作って ARN 限定。
  }
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name   = "${local.name}-ecs-secrets"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_secrets.json
}

# ---- タスクロール: アプリ自身が使う AWS 権限 ----
resource "aws_iam_role" "ecs_task" {
  name               = "${local.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = { Name = "${local.name}-ecs-task" }
}

# ADOT sidecar が AMP へメトリクスを remote_write するための権限。
data "aws_iam_policy_document" "ecs_task_amp" {
  statement {
    sid    = "AmpRemoteWrite"
    effect = "Allow"
    actions = [
      "aps:RemoteWrite",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
    ]
    resources = [aws_prometheus_workspace.main.arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_amp" {
  name   = "${local.name}-ecs-task-amp"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_amp.json
}
