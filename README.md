# 個人用 AI 統合型カンバンボード (仮)

[![CI](https://github.com/makotonic999/my-kanban-app/actions/workflows/ci.yml/badge.svg)](https://github.com/makotonic999/my-kanban-app/actions/workflows/ci.yml)

「Go × PostgreSQL × SRE」の実務スキル向上および、最終的なモバイルアプリ（Google Play）リリースを目指す個人開発プロジェクト。
日々のタスク管理に加え、1年分のログをAI（LLM）が分析してパーソナルな振り返りをフィードバックするWeb/モバイルアプリケーション。

---

## 🗺 開発ロードマップ

### フェーズ 1：DBの基礎とシンプルカンバンボード構築
- [x] Docs as Code（Markdownによるテーブル定義書・ER図のGitHub管理）
- [x] データモデリング（1:N, N:M リレーション、正規化）
- [x] Go + PostgreSQL によるシンプルなカンバンボードWeb API構築
- [x] インデックス基礎（B-Tree）と基本クエリの実行計画（`EXPLAIN`）確認

### フェーズ 2：SRE & オブザーバビリティ追加
- [x] OpenTelemetry を用いた Go API および DBクエリのトレーシング導入
- [x] Prometheus + Grafana によるメトリクス可視化（p95 / p99 レイテンシなど）
- [x] SLO（サービスレベル目標）の定義およびエラー予算（Error Budget）の監視運用

### フェーズ 3：API完成 & 認証 & テスト
- [x] 残API実装（タスクの更新・削除、タグのCRUD）
- [x] JWT認証の実装（ログイン・トークン検証・ミドルウェア）
- [x] 認可の実装（各ユーザーは自分のタスク/タグのみ操作可能。他人のリソースは 404）
- [x] ユニットテスト・統合テスト（`testing` パッケージ + `httptest` / `go-sqlmock`、統合は `test-auth.ps1`）
- [x] APIドキュメント整備（OpenAPI / Swagger）

### フェーズ 4：AWS配置 & インフラ構築
- [x] インフラ構成（ECS Fargate + RDS PostgreSQL + ALB）を Terraform で設計（`terraform/`、`plan` 通過）
- [x] IaC（Terraform）によるインフラのコード化（NAT トグル・アカウントガード・SSMシークレット）
- [ ] 本番適用（`terraform apply`）※フロントエンド完成後に実施予定
- [x] CI/CDパイプライン構築（GitHub Actions）— CI稼働中 / CDはOIDCでコード化（apply後に有効化）
- [x] 本番環境へのSRE設定反映（AMP + Amazon Managed Grafana + ADOT）を Terraform 化（`plan` 通過）

### フェーズ 5：Webフロントエンド構築
- [ ] React（または Next.js）によるカンバンボードUI実装
- [ ] JWT認証フロー（ログイン・セッション管理）
- [ ] AWS S3 + CloudFront によるホスティング

### フェーズ 6：AI機能の実装 & データ基盤整備
- [ ] AI（LLM）が集計しやすいDB構造・クエリへのリファクタリング
- [ ] 大量ダミーデータ（10万〜100万件）に対する集計クエリ最適化（`GROUP BY`、マテリアライズドビュー等）
- [ ] LLM API（OpenAI / Gemini）と Go バックエンドの連携実装
- [ ] 1年間のタスクログから年間サマリー・振り返りフィードバック文を自動生成
- [ ] AI評価（Eval）手法の確立（ハルシネーション検出、生成結果の品質テスト自動化）
- [ ] 必要に応じたベクトル検索（`pgvector` 等）の検討

### フェーズ 7：スマホアプリ化 & Google Playストア公開
- [ ] モバイルアプリ（Flutter / React Native）によるUI構築
- [ ] Web / アプリ共通のAPI・認証基盤を活用したアカウント連携
- [ ] Google Play Console でのビルド・申請・リリース

---

## 📂 ドキュメント構成 (`/docs`)
- [`docs/db/users.md`](docs/db/users.md): usersテーブル定義書
- [`docs/db/tasks.md`](docs/db/tasks.md): tasksテーブル定義書
- [`docs/db/tags.md`](docs/db/tags.md): tags / task_tagsテーブル定義書
- [`docs/db/erd.md`](docs/db/erd.md): ER図
- [`docs/PROMETHEUS_METRICS.md`](docs/PROMETHEUS_METRICS.md): Prometheusメトリクス定義書
- [`docs/SLO.md`](docs/SLO.md): SLO / エラー予算 定義書
- [`docs/openapi.yaml`](docs/openapi.yaml): OpenAPI 3.0 APIドキュメント（全10パス・JWT Bearer認証）
- [`docs/TEST_EVIDENCE.md`](docs/TEST_EVIDENCE.md): テストエビデンス（実行ログ・カバレッジ）
- [`docs/HANDOVER.md`](docs/HANDOVER.md): 引継ぎドキュメント（開発進捗・次のステップ）

---

## ✅ テスト & 品質

認証・認可という壊れると被害が大きい領域を、**テストピラミッド**で多層的に検証しています。

### テスト構成
| 種別 | 対象 | ツール | 件数 |
|---|---|---|---|
| ユニット | JWT発行・検証（改ざん / 失効 / alg混同攻撃 の拒否） | `testing` | 8 |
| ユニット | ログイン（bcrypt照合・ユーザー列挙対策・入力検証） | `go-sqlmock` | 4 |
| ユニット | 認証ミドルウェア + context伝播 | `httptest` | 5 |
| ユニット | **認可**（自分のタスクのみ操作・他人は404・作成は本人ID） | `go-sqlmock` | 6 |
| 統合(E2E) | Docker + PostgreSQL + API を通した実動作 & クロスユーザー分離 | `test-auth.ps1` | 12 |

- **ユニット/HTTPテスト 23件・全PASS**、`internal/auth` パッケージのカバレッジ **92.3%**。
- 統合テストは **User A のタスクに User B がアクセスできない（404）** ことまで実環境で確認済み。

### 実行方法
```bash
# ユニットテスト（DB/Docker不要・高速）
go test ./... -count=1 -v
go test ./... -cover

# 統合テスト（要 docker compose）
docker compose up -d --build
./test-auth.ps1        # 全12チェック、成功で EXITCODE=0
```

### セキュリティ設計のポイント
- **認可の source of truth はトークン**: 作成時の所有者や一覧のフィルタは、リクエストボディではなく JWT 由来の userID で決定（なりすまし防止）。
- **存在を漏らさない**: 他ユーザーのリソースは 403 ではなく **404** を返し、IDの存在有無を推測させない。
- **秘密情報は環境変数のみ**: `JWT_SECRET` はコード/gitに置かず環境変数管理（`.env` は gitignore）。

実行ログ・カバレッジの詳細は [`docs/TEST_EVIDENCE.md`](docs/TEST_EVIDENCE.md) を参照。

---

## 🔄 CI/CD（GitHub Actions）

長期の AWS アクセスキーを持たない **OIDC（シークレットレス）** 方式を採用。

### CI（`.github/workflows/ci.yml`）— push / PR で自動実行
- **Go**: gofmt チェック → `go vet` → `go build` → `go test -race -cover`
- **Terraform**: `fmt -check` → `init -backend=false` → `validate`
- AWS 不要・課金なしで毎回動作。

### CD（`.github/workflows/cd.yml`）— `main` push で AWS へデプロイ
1. GitHub OIDC で IAM ロールを一時 assume（アクセスキー不要）
2. Docker イメージをビルドして **ECR** に push（`sha` と `latest`）
3. タスク定義を再レンダリングして **ECS サービスを更新**（安定するまで待機）

- OIDC 用 IAM ロールは Terraform（[`terraform/oidc_github.tf`](terraform/oidc_github.tf)）で管理。信頼ポリシーは当該リポジトリの `main`/タグに限定。
- CD が実際に流れるのは **インフラ `apply` 済み** かつ リポジトリ変数 `AWS_ROLE_ARN` 設定後。未設定時は安全に skip。

> セットアップ手順: `terraform apply` → `terraform output github_actions_role_arn` の値を
> GitHub リポジトリの **Variables** に `AWS_ROLE_ARN` として登録すると CD が有効化される。
