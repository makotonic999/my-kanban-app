# dev-log: 2026-10-01 — 無料枠 Web 公開のコード側下準備

## この日やったこと
「C（自分でも使う＋ポートフォリオ公開）」を月額 $0 で実現するため、
**Cloudflare Pages（フロント）+ Render（API）+ Neon（DB）** 構成に向けたコード側の下準備を行った。
コード本体はほぼ変更せず、公開で詰まる点だけ手当て + 設定ファイル + 手順書を用意。

### サービス選定の確定（基準に基づく・最新の無料枠を確認）
- フロント: **Cloudflare Pages**（静的配信・帯域無制限・ビルド 500/月・$0）。
- API: **Render 無料**（Go/Docker がそのまま載る・$0。15 分アイドルでスリープ→起動 ~1 分）。
  - 補足: Fly.io は無料枠を廃止（試用のみ）、Railway は実質月 $5 最低、のため Render を採用。
- DB: **Neon 無料**（本物の Postgres・スケールゼロ・0.5GB/100 CU-hours・$0）。
- 設計「コードは 1 つ、設定で分ける」に沿い、**リポジトリ/ブランチは分けない**。環境変数だけで配線。

## 実装（コード側下準備）
### A. PORT 対応（`cmd/api/main.go`）
- `os.Getenv("PORT")` があればそれで待受、無ければ従来どおり `8080`（後方互換）。
- Render は `PORT` を自動注入するため必須の対応。

### B. DB 接続の起動時リトライ（`internal/db/db.go`）
- `Ping` 失敗時に 1s,2s,...×最大 10 回（~55s）リトライ。全失敗時のみ `log.Fatal`。
- Neon のスケールゼロ・コールドスタートや compose の起動順ズレに耐える。失敗時だけ効くので後方互換。

### C. 公開用スキーマ（`db/schema.sql`・新規）
- `init.sql` + rules + task_status_events を **冪等**（`CREATE TABLE/INDEX IF NOT EXISTS`・`ADD COLUMN IF NOT EXISTS`）に 1 本化。
- Neon に 1 回流せば全テーブルが揃う。既存 DB への再適用も安全。

### D. Render Blueprint（`render.yaml`・新規）
- `type: web / runtime: docker / plan: free`、`healthCheckPath: /metrics`。
- 環境変数の枠: `DATABASE_URL`/`JWT_SECRET`/`CORS_ALLOWED_ORIGINS`（sync:false=ダッシュボード入力）、`OTEL_...`は空。

### F. 公開手順書（`docs/DEPLOY_FREE_TIER.md`・新規）
- **Neon → Render → Cloudflare** の順（後のサービスが前の URL を要るため）。
- 各ステップのブラウザ操作、環境変数の配線（`VITE_API_BASE_URL`/`DATABASE_URL`/`CORS_ALLOWED_ORIGINS`）、
  Cloudflare のビルド設定（Root=`frontend` / build=`npm run build` / 出力=`dist`）、
  動作確認、トラブルシュート、コスト運用メモまで記載。

## 検証エビデンス
- `go build` / `go vet` / `gofmt` / `go test ./...` すべて OK。
- `db/schema.sql` を稼働中 DB に `ON_ERROR_STOP=1` で適用 → エラーなし（NOTICE: skipping のみ）、
  テーブル数 5・既存データ件数不変（冪等・非破壊を確認）。
- api 再ビルドで PORT 未設定時 `Server running on :8080`（後方互換）、`/metrics` 200、登録→ログイン 200。

## 次のステップ（ユーザー作業が主）
- 手順書に従い Neon → Render → Cloudflare をセットアップ（アカウント作成・環境変数の配線）。
- スマホのレスポンシブ最適化は後回し（Web 公開自体はスマホのブラウザでも利用可）。
- 将来の改善: マイグレーション自動化（現状は schema.sql の手動適用）。
