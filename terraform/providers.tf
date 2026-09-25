terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # NOTE: 学習/ポートフォリオ用途のためステートはローカル。
  # 本番運用時は S3 バックエンド（ネイティブロック）に切り替える想定。
  # backend "s3" { ... }
}

# provider にプロファイルを明示し、意図しないアカウントへの適用を防ぐ。
provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "my-kanban-app"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# 現在の呼び出し元アカウントを取得（アカウントガードに使用）。
data "aws_caller_identity" "current" {}

# 想定した dev アカウント以外に適用しようとしたら plan/apply を失敗させる安全弁。
# （SSO でプロファイルを間違える事故を防ぐ）
check "account_guard" {
  assert {
    # allowed_account_id が空（未注入）ならガードをスキップ。
    # 注入されている場合のみ、呼び出し元アカウントとの一致を要求する。
    condition     = var.allowed_account_id == "" || data.aws_caller_identity.current.account_id == var.allowed_account_id
    error_message = "適用先アカウント(${data.aws_caller_identity.current.account_id})が想定(${var.allowed_account_id})と異なります。プロファイルを確認してください。"
  }
}

# 利用可能なアベイラビリティゾーン（先頭2つを使う）。
data "aws_availability_zones" "available" {
  state = "available"
}
