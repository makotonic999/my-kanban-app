# 個人用 AI 統合型カンバンボード (仮)

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
- [ ] JWT認証の実装（ログイン・トークン検証・ミドルウェア）
- [ ] ユニットテスト・統合テスト（`testing` パッケージ + `testcontainers`）
- [ ] APIドキュメント整備（OpenAPI / Swagger）

### フェーズ 4：AWS配置 & インフラ構築
- [ ] インフラ構成（ECS Fargate + RDS PostgreSQL + ALB）
- [ ] IaC（Terraform または AWS CDK）によるインフラのコード化
- [ ] CI/CDパイプライン構築（GitHub Actions）
- [ ] 本番環境へのSRE設定反映（Prometheus / Grafana / SLO）

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
- [`docs/HANDOVER.md`](docs/HANDOVER.md): 引継ぎドキュメント（開発進捗・次のステップ）
