# GitHub Actions からの OIDC 連携（シークレットレス CD）。
# 長期 AWS アクセスキーを GitHub に置かず、実行時に一時クレデンシャルを assume する。

variable "github_owner" {
  description = "GitHub のオーナー（ユーザー/組織）名"
  type        = string
  default     = "makotonic999"
}

variable "github_repo" {
  description = "GitHub リポジトリ名"
  type        = string
  default     = "my-kanban-app"
}

variable "enable_github_oidc" {
  description = "GitHub Actions 用 OIDC ロールを作成するか（CD を使うとき true）"
  type        = bool
  default     = true
}

# GitHub の OIDC プロバイダ。アカウントに1つだけ存在すればよい。
resource "aws_iam_openid_connect_provider" "github" {
  count = var.enable_github_oidc ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = { Name = "${local.name}-github-oidc" }
}

# 信頼ポリシー: このリポジトリからのワークフローのみがこのロールを assume できる。
data "aws_iam_policy_document" "github_assume" {
  count = var.enable_github_oidc ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # 特定リポジトリの main ブランチとタグに限定（最小権限の入口）。
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_owner}/${var.github_repo}:ref:refs/tags/*",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  count              = var.enable_github_oidc ? 1 : 0
  name               = "${local.name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume[0].json
  tags               = { Name = "${local.name}-github-actions" }
}

# CD が必要とする最小権限:
# - ECR: ログイン用トークン取得 + このリポジトリへの push/pull
# - ECS: サービス更新 + タスク定義登録
# - IAM PassRole: タスク定義に付与する実行/タスクロールを ECS に渡す
data "aws_iam_policy_document" "github_actions" {
  count = var.enable_github_oidc ? 1 : 0

  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # GetAuthorizationToken はリソース限定不可
  }

  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  statement {
    sid    = "EcsDeploy"
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
    ]
    resources = ["*"] # ECS の多くの API はリソース ARN 指定に制約があるため *（条件で絞るのは今後の課題）
  }

  statement {
    sid       = "PassEcsRoles"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.ecs_execution.arn, aws_iam_role.ecs_task.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_actions" {
  count  = var.enable_github_oidc ? 1 : 0
  name   = "${local.name}-github-actions"
  role   = aws_iam_role.github_actions[0].id
  policy = data.aws_iam_policy_document.github_actions[0].json
}

output "github_actions_role_arn" {
  description = "GitHub Actions の CD が assume する IAM ロール ARN（GitHub Secrets/Variables に設定）"
  value       = var.enable_github_oidc ? aws_iam_role.github_actions[0].arn : null
}
