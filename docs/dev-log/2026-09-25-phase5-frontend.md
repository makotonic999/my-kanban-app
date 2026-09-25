# dev-log: 2026-09-25（フェーズ5 着手）— React フロントエンド + CORS 対応

## この日やったこと
フェーズ5「Web フロントエンド構築」に着手。**React 18 + Vite + TypeScript + Tailwind CSS** で
カンバンボード UI を実装し、フェーズ3の JWT 認証フローと接続。フロント(別オリジン)から Go API を
叩くための **CORS ミドルウェア**をバックエンドに追加した。あわせてフロント配信用の Terraform
（`terraform/frontend_hosting.tf`）を用意。

> 補足: 作業中に自宅のブレーカーが落ちて一度中断。復帰時に git で点検したところ、コミット済みの
> 喪失はゼロで、未コミットの作業ツリーとして本作業一式が残っていた。ビルド・テストで健全性を
> 確認したうえで、このコミットにまとめている。

## 実装
### フロントエンド（`frontend/`・新規）
- ビルド基盤: `vite.config.ts`（`/api` → `localhost:8080` の dev プロキシで CORS を回避）、
  `tailwind.config.js` / `postcss.config.js` / `tsconfig.json`（`strict` + `noUnusedLocals` 等）。
- `src/types.ts`: Go の `model.Task` に対応する型（`TaskStatus = todo | in_progress | done` ほか）。
- `src/api.ts`: fetch ラッパ。`Authorization: Bearer` 付与、`localStorage` によるトークン管理、
  401 を `ApiError` として型で表現。エンドポイントは `/login` `/users` `/tasks` `/tasks/{id}`
  `/tasks/{id}/complete` — **バックエンドのルート登録と一致**。
- `src/components/Login.tsx`: ログイン / 新規登録のトグル UI。401 は文言を出し分け。
- `src/components/Board.tsx`: 3 カラム（To Do / In Progress / Done）のカンバン。作成・ステータス
  移動（done は `/complete` を使用）・削除。401 検知でログアウトへ委譲。
- `src/App.tsx` / `src/main.tsx`: トークン有無で Login/Board を出し分け。

### バックエンド（CORS）
- `internal/middleware/cors.go`: 許可オリジンを `CORS_ALLOWED_ORIGINS`（カンマ区切り、既定は
  Vite の `localhost:5173`）から取得。OPTIONS プリフライトを **認証より前**に 204 で返す。
  最外層に適用するため `cmd/api/main.go` で `middleware.CORS(handlerWithMetrics)` に配線。
- `internal/middleware/cors_test.go`: 許可オリジン / プリフライト / 不許可オリジンの 3 ケース。

### インフラ / ローカル開発
- `terraform/frontend_hosting.tf`: フロント静的配信（S3 + CloudFront）用の Terraform（`plan` 未検証）。
- `docker-compose.yml`: `JWT_SECRET`（ローカル用既定値）と `CORS_ALLOWED_ORIGINS` を追加。

## 検証エビデンス
- バックエンド: `go build ./...` = 0、`go vet ./...` = 0。
- バックエンド: `go test ./...` = 全 ok（auth / handler / middleware。CORS 3 テスト含む）。
- フロント: `npm run build`（= `tsc --noEmit` 型チェック + `vite build`）= 成功。
  34 modules transformed、`dist/` 生成（js 149KB / gzip 48KB）。
- 整合性: フロントの API パスと `main.go` のルート登録が一致。ログインレスポンス `{token}` を
  フロントが読み取り Bearer 認証で保護ルートを呼ぶ流れも一致。

## アーキテクチャ
```
[Browser] React(Vite :5173)
    │  dev: /api → proxy → :8080  /  prod: VITE_API_BASE_URL → API origin
    ▼
[Go API :8080]  CORS(最外層) → Metrics → Mux → RequireAuth(保護ルート)
    │
    ▼
[PostgreSQL]
```

## 学び / 割り切り
- **開発は Vite プロキシ・本番は CORS** の二本立て。dev は同一オリジン扱いで CORS を回避しつつ、
  本番(CloudFront ↔ API で別オリジン)に備えてサーバ側 CORS も用意した。
- プリフライト(OPTIONS)は**認証の前**に返す必要がある（ブラウザは Authorization を付けずに送るため）。
  CORS を最外層に置くのがポイント。
- 401 を `ApiError` として型に落とし、UI 側で「自動ログアウト」に一元的に接続。
- `frontend_hosting.tf` は追加のみで `plan` 未検証、compose へのフロントサービス定義も未追加（今後）。

## 次のステップ
- [ ] `docker compose` にフロントサービスを追加（or ビルド成果物を配信）
- [ ] フロントの E2E/コンポーネントテスト、lint(eslint) 導入の検討
- [ ] フロント完成後にインフラ一式を `apply` → CD 実走

## 追記: フロント配信インフラ `plan` 通過（同日）
`terraform/frontend_hosting.tf`（S3 非公開 + CloudFront + OAC + SPA ルーティング Function）の
`plan` を検証。フェーズ4 までと同じ「`plan` 通過まで（`apply` は課金のため後回し）」の到達点に揃えた。

### 検証エビデンス
- `terraform fmt -check -recursive` = 0、`terraform validate` = Success。
- `terraform plan` = **Plan: 56 to add, 0 to change, 0 to destroy**（従来 48 + フロント配信 8）。
  警告は CloudFront Function 等の想定内のみ、エラーなし。
- アカウントガード = 適用先 `532970129307`（dev）で想定一致。
- フロント配信 8 リソースが計画に含まれることを確認:
  `aws_s3_bucket.frontend` / `_public_access_block` / `_versioning` /
  `aws_cloudfront_origin_access_control.frontend` / `aws_cloudfront_function.spa_router` /
  `aws_cloudfront_distribution.frontend` / `aws_s3_bucket_policy.frontend` / `random_id.frontend_suffix`。
- output に `frontend_bucket` / `frontend_cloudfront_domain` / `frontend_distribution_id` を追加
  （デプロイ時の同期先・キャッシュ無効化に使用）。
- **`apply` 未実施**（課金なし）。plan 成果物はコミットせず削除。
