# Terraform — AWS インフラ（フェーズ4）

my-kanban-app を AWS 上で動かすためのインフラを Terraform でコード化したもの。
対象アカウントは **dev (`532970129307`)**、リージョンは **ap-northeast-1（東京）**。

> ⚠️ 現状は `terraform plan` が通る状態まで。実 `apply`（課金発生）はフロントエンド完成後に行う想定。

---

## アーキテクチャ

```
                 Internet
                    │
              ┌─────▼─────┐
              │    ALB     │  (public subnets, :80)
              └─────┬──────┘
                    │  forward
           ┌────────▼─────────┐
           │  ECS Fargate      │  (api タスク, :8080)
           │  desired_count=1  │
           └────────┬──────────┘
                    │ 5432 (SG 制限)
              ┌─────▼─────┐
              │    RDS     │  (private subnets, PostgreSQL 16)
              └────────────┘

  ECR: api イメージ格納    SSM Parameter Store: DATABASE_URL / JWT_SECRET (SecureString)
  CloudWatch Logs: /ecs/kanban-dev-api
```

- **2 AZ** に public / private サブネットを配置（ALB・RDS の冗長性要件を満たす）。
- **RDS は private・非公開**。ECS のセキュリティグループからの 5432 のみ許可。
- **シークレットはコードに書かない**。`random_password` で生成 → SSM SecureString → ECS 実行時に注入。

---

## コスト設計（重要）

| リソース | 課金の性質 | 概算(月) |
|---|---|---|
| ALB | 起動時間 + 処理量 | ~$18-22 |
| RDS db.t4g.micro | 起動時間 + ストレージ | ~$13-16 |
| Fargate 0.25vCPU/0.5GB ×1 | タスク起動時間 | ~$9-12 |
| NAT Gateway（任意） | 起動時間 + データ量 | ~$32-38 |
| ECR / CloudWatch 等 | 使用量 | 数ドル |

- 多くは「立てておく時間」への課金。**使わない時は `terraform destroy` で固定費を止める**運用を前提にする。
- **`enable_nat_gateway = false`（デフォルト）** で NAT の月額固定費を回避（Fargate を public サブネットに置き public IP で外部通信）。
- 正確な料金は [AWS Pricing Calculator](https://calculator.aws/) で確認すること。

---

## 前提

- Terraform >= 1.5
- AWS SSO で dev プロファイルにログイン済みであること:
  ```powershell
  aws sso login --profile dev
  aws sts get-caller-identity --profile dev   # Account が 532970129307 であること
  ```

## 使い方

```powershell
cd terraform

terraform init
terraform fmt
terraform validate
terraform plan            # 変更なし・課金なし。ここまでが現状のゴール

# 実際に構築する場合（課金発生）:
# terraform apply
# ... デモ後 ...
# terraform destroy        # 固定費を止める
```

### NAT を有効化（本番相当）する場合
```powershell
terraform plan  -var="enable_nat_gateway=true"
terraform apply -var="enable_nat_gateway=true"
```

---

## 安全設計

- **provider に `profile = "dev"` を明示**し、誤って別アカウントへ適用する事故を防止。
- **アカウントガード**（`providers.tf` の `check "account_guard"`）: 適用先が `allowed_account_id`（既定 dev）と異なると plan/apply を失敗させる。
- ステートはローカル（学習用途）。本番運用時は S3 バックエンド（ネイティブロック）へ移行する（`providers.tf` にコメントで方針記載）。
- `.gitignore` で `*.tfstate` / `.terraform/` / `*.tfvars` を除外（状態・機密の混入防止）。

---

## デプロイの流れ（apply する場合の全体像）

1. `terraform apply` でインフラ作成（ECR / RDS / ALB / ECS など）。
2. api の Docker イメージをビルドして ECR に push（`app_image_tag` と一致させる）。
3. ECS サービスがイメージを pull してタスク起動。DB マイグレーション（`db/init.sql`）の適用手段は別途用意（初回のみ）。
4. `terraform output alb_dns_name` のエンドポイントにアクセス。
5. 使い終わったら `terraform destroy`。

> CI/CD（GitHub Actions による push→build→ECR→ECS 更新）は本フェーズの次のタスク。

---

## 構成ファイル

| ファイル | 内容 |
|---|---|
| `providers.tf` | provider / バージョン / アカウントガード / AZ 取得 |
| `variables.tf` | 変数（リージョン・NAT トグル・RDS/Fargate サイズ等） |
| `network.tf` | VPC / サブネット / IGW / ルート / 任意 NAT |
| `security_groups.tf` | ALB / ECS / RDS の SG（最小権限） |
| `ecr.tf` | ECR リポジトリ + ライフサイクル |
| `rds.tf` | RDS PostgreSQL + SSM シークレット |
| `alb.tf` | ALB / ターゲットグループ / リスナー |
| `iam.tf` | ECS 実行ロール / タスクロール |
| `ecs.tf` | クラスタ / タスク定義 / サービス / ログ |
| `outputs.tf` | 主要リソースの出力 |
