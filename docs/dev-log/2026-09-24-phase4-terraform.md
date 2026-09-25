# dev-log: 2026-09-24（フェーズ4 着手）— Terraform で AWS インフラをコード化

## この日やったこと
フェーズ4「AWS配置 & インフラ構築」に着手。ECS Fargate + RDS + ALB の構成を Terraform で記述し、
**`terraform plan` が通る状態**まで到達（`apply` はフロント完成後に実施予定）。

## 前提の確認（着手前にやったこと）
- IaC は **Terraform** に統一（DIVE プロジェクトと揃える）。
- デプロイ先は **dev アカウント `123456789012`** / **ap-northeast-1**。
  - 最初 `sts get-caller-identity` が `761018859875`（root）を指していて中断 → 正しい dev プロファイルを特定。
  - `~/.aws/config` を確認し、プロファイル `dev`（SSO, AdministratorAccess, 123456789012）を使用と決定。
  - SSO トークン期限切れ → `aws sso login --profile dev` 後に再確認、`assumed-role/.../dev` で dev を指すことを検証。
- コスト方針: 固定費（ALB/RDS/NAT）が「立てている時間」に課金される点を確認。
  **NAT はデフォルト無効**（月~$35 回避）、`apply`/`destroy` で立て消しする運用を前提に。

## 実装（terraform/ 配下・フラット構成）
- `providers.tf`: aws ~>5.60 + random ~>3.6。**provider に profile=dev 明示**。`default_tags`。
  **アカウントガード**（`check` ブロックで想定アカウント以外なら失敗）。
- `variables.tf`: リージョン・`enable_nat_gateway`(既定 false)・RDS(db.t4g.micro/16.4/20GB)・Fargate(256/512/1)。
- `network.tf`: VPC(10.0.0.0/16)、2AZ の public/private サブネット、IGW、ルート、任意 NAT。
  NAT 無効時は Fargate を public に置き public IP 付与（locals で切替）。
- `security_groups.tf`: ALB(80 from internet) / ECS(app port from ALB のみ) / RDS(5432 from ECS のみ)。
- `ecr.tf`: リポジトリ + scan_on_push + 直近10イメージ保持。
- `rds.tf`: `random_password` 生成 → RDS(private, 非公開) + **SSM SecureString**(db_password/database_url/jwt_secret)。
- `alb.tf`: ALB + TG(target_type=ip) + HTTP:80 リスナー。health check は `/metrics`(認証不要で200)。
- `iam.tf`: ECS 実行ロール(+AmazonECSTaskExecutionRolePolicy +SSM読取/KMS復号) / タスクロール。
- `ecs.tf`: クラスタ(containerInsights) / ロググループ(14日) / タスク定義(X86_64, secrets を SSM から注入) / サービス(ALB 連携)。
- `outputs.tf`: alb_dns_name / ecr_repository_url / rds_endpoint / cluster / service / nat_gateway_enabled。

## 検証エビデンス
- `terraform fmt` → network.tf 整形。
- `terraform init` → aws 5.100.0 / random 3.9.1 取得成功。
- `terraform validate` → **Success! The configuration is valid.**
- `terraform plan` → **Plan: 36 to add, 0 to change, 0 to destroy**。警告・エラーなし。
  - アカウントガードは沈黙（= dev 123456789012 に正しく向いている）。
  - `nat_gateway_enabled = false`。
- **`apply` は未実施**（課金なし）。

## 設計上のポイント（学び）
- **クラウド課金の多くは「使用量」でなく「起動時間」**。ユーザー0でも ALB/RDS/NAT は課金される。
  → 学習用途は destroy 前提、NAT はトグルで最小化。
- **シークレットをコード/環境変数直書きしない**。SSM SecureString + ECS の `secrets` で実行時注入。
- **誤アカウント適用の防止**: provider の profile 明示 + `check` によるアカウントガード。
- health check に専用エンドポイントが無いので、認証不要で 200 を返す `/metrics` を流用。
  （将来は `/healthz` を実装するのが望ましい。）

## 残課題 / 次のステップ
- [ ] CI/CD（GitHub Actions: push → build → ECR push → ECS 更新）
- [ ] 本番 SRE 設定（Prometheus/Grafana/SLO）の反映
- [ ] `/healthz` 専用ヘルスチェックエンドポイントの追加
- [ ] DB マイグレーション（`db/init.sql`）の適用手段（初回）
- [ ] `apply` 実行（フロント完成後、デモ時に apply→destroy）
- [ ] 本番はステートを S3 バックエンドへ、KMS を CMK 化して権限厳密化
