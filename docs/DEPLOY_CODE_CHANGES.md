# 無料枠 Web 公開に向けたコード下準備 — 変更まとめ

無料枠構成（**Cloudflare Pages + Render + Neon**／月額 $0 狙い）で Web 公開するために、
コード側で行った下準備の一覧。**コード本体のロジックは変えず**、公開で詰まる点の手当てと
設定ファイル・手順書の追加のみ。すべて後方互換（ローカルの既存動作は不変）。

> 実際の公開手順は [`docs/DEPLOY_FREE_TIER.md`](DEPLOY_FREE_TIER.md) を参照。
> 作業当日の記録は [`docs/dev-log/2026-10-01-deploy-free-tier-prep.md`](dev-log/2026-10-01-deploy-free-tier-prep.md)。
> 反映 PR: #19（`feat: 無料枠Web公開のコード側下準備`）。

---

## 変更一覧

| 種別 | ファイル | 内容 | なぜ必要か |
|---|---|---|---|
| 変更 | `cmd/api/main.go` | `PORT` 環境変数対応（未設定なら 8080） | Render は待受ポートを `PORT` で注入するため |
| 変更 | `internal/db/db.go` | 起動時の DB 接続リトライ（最大10回） | Neon のコールドスタートや起動順ズレで初回接続が失敗しても落ちないように |
| 新規 | `db/schema.sql` | 冪等な公開用スキーマ（全テーブル1本化） | Neon に1回流せば全テーブルが揃う。再実行も安全 |
| 新規 | `render.yaml` | Render Blueprint（Docker/free/ヘルスチェック/env枠） | ダッシュボードから Blueprint 一発でAPIサービスを定義 |
| 新規 | `docs/DEPLOY_FREE_TIER.md` | 公開手順書（Neon→Render→Cloudflare） | ブラウザ操作と環境変数の配線を順に実行するため |

---

## 詳細

### 1. `cmd/api/main.go` — PORT 対応
- `os.Getenv("PORT")` があればそのポートで待受、無ければ従来どおり `8080`。
- Render は実行時に `PORT` を注入する。ローカル（compose）は未設定なので 8080 のまま＝**後方互換**。

```go
port := os.Getenv("PORT")
if port == "" {
    port = "8080"
}
log.Fatal(http.ListenAndServe(":"+port, handler))
```

### 2. `internal/db/db.go` — 接続リトライ
- `Ping` 失敗時に 1s, 2s, … と間隔を空けて最大 10 回（合計 ~55s）リトライ。
- 全失敗時のみ `log.Fatal`。成功すればすぐ返る＝**正常時は従来と同じ挙動**。
- 目的: Neon のスケールゼロ（アイドルで停止→クエリで復帰）や、compose の `db` が
  healthy になる前に `api` が起動したケースで、一発接続失敗で落ちるのを防ぐ。

### 3. `db/schema.sql` — 冪等な公開用スキーマ
- `db/init.sql`（users/tasks/tags/task_tags/task_status_events、rules 列含む）を
  `CREATE TABLE IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS` で**冪等化**。
- Neon のような新規 DB に1回流せば全テーブルが揃う。既存 DB への再適用も安全（skip されるだけ）。
- 検証: 稼働中ローカル DB に `ON_ERROR_STOP=1` で適用 → エラーなし・テーブル5・既存データ件数不変。

### 4. `render.yaml` — Render Blueprint
- `type: web / runtime: docker / plan: free`、`healthCheckPath: /metrics`。
- 環境変数の枠（値はダッシュボードで入力）:
  - `DATABASE_URL`（Neon 接続文字列・`sslmode=require` 込み）
  - `JWT_SECRET`（十分長いランダム値）
  - `CORS_ALLOWED_ORIGINS`（Cloudflare のフロント URL）
  - `OTEL_EXPORTER_OTLP_ENDPOINT`（空＝監視未接続）
- `PORT` は Render が自動注入するため記載不要。

### 5. `docs/DEPLOY_FREE_TIER.md` — 公開手順書
- 順番は **Neon → Render → Cloudflare**（後のサービスが前のサービスの URL を要るため）。
- 各ステップのブラウザ操作、環境変数の配線、Cloudflare のビルド設定
  （Root=`frontend` / build=`npm run build` / 出力=`dist`）、動作確認、トラブルシュートを収録。

---

## 設計の勘所（なぜこれで済むか）
- 本プロジェクトは「**コードは1つ、設定（環境変数）で環境を分ける**」設計。
  だから公開でも **ロジック改修はほぼ不要**で、必要なのは「ポート/接続の堅牢化」と「配線情報」だけ。
- リポジトリもブランチも分けない。3 サービスが同じ main の必要な部分を見るだけ:
  - Render → ルートの `Dockerfile`
  - Cloudflare → `frontend/` をビルド
  - Neon → `db/schema.sql` を1回流す

## 検証エビデンス（下準備時点）
- `go build` / `go vet` / `gofmt` / `go test ./...` 全 OK。
- `db/schema.sql` 冪等・非破壊を実 DB で確認。
- PORT 未設定時 `:8080` 起動・`/metrics` 200・登録→ログイン 200（後方互換）を確認。

## 残作業（ユーザー）
- `docs/DEPLOY_FREE_TIER.md` に沿って 3 サービスをセットアップ（アカウント作成・環境変数設定）。
- 無料枠は変動するため、作業前に各サービスの料金ページで最新を確認。
- スマホのレスポンシブ最適化は後回し（Web 公開自体はスマホのブラウザでも利用可）。
