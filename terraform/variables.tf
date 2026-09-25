variable "aws_profile" {
  description = "使用する AWS CLI プロファイル名（誤アカウント防止のため明示）"
  type        = string
  default     = "dev"
}

variable "allowed_account_id" {
  description = <<-EOT
    適用を許可する AWS アカウントID（アカウントガード）。
    実 ID はコミットせず、`terraform.tfvars`（gitignore 済み）や環境変数
    `TF_VAR_allowed_account_id` で注入する。空の場合はガードを実質無効化する。
  EOT
  type        = string
  default     = ""
}

variable "region" {
  description = "デプロイ先リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "環境名（タグ・命名に使用）"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "リソース命名のプレフィックス"
  type        = string
  default     = "kanban"
}

# ---- ネットワーク ----
variable "vpc_cidr" {
  description = "VPC の CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "使用するアベイラビリティゾーン数（ALB/RDS の要件上 2 以上）"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = <<-EOT
    NAT Gateway を作成するか。
    - false（デフォルト・コスト最適）: Fargate を public サブネットに置き public IP で外部通信。NAT の月額固定費(~$35)を回避。
    - true（本番相当）: Fargate を private サブネットに置き NAT 経由で外部通信。
  EOT
  type        = bool
  default     = false
}

# ---- RDS ----
variable "db_name" {
  description = "アプリDB名"
  type        = string
  default     = "kanban"
}

variable "db_username" {
  description = "RDS マスターユーザー名"
  type        = string
  default     = "kanban"
}

variable "db_instance_class" {
  description = "RDS インスタンスクラス（最小構成）"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS ストレージ(GB)"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL エンジンバージョン"
  type        = string
  default     = "16.4"
}

# ---- ECS / アプリ ----
variable "app_image_tag" {
  description = "ECS が参照する ECR イメージタグ"
  type        = string
  default     = "latest"
}

variable "app_container_port" {
  description = "アプリのリッスンポート"
  type        = number
  default     = 8080
}

variable "app_cpu" {
  description = "Fargate タスクの CPU ユニット（256 = 0.25 vCPU）"
  type        = number
  default     = 256
}

variable "app_memory" {
  description = "Fargate タスクのメモリ(MiB)"
  type        = number
  default     = 512
}

variable "app_desired_count" {
  description = "常時起動するタスク数"
  type        = number
  default     = 1
}
