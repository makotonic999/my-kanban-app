# dev-log: 2026-09-25（フェーズ5 続き）— フロントのデプロイ経路整備

## この日やったこと
フロントエンドを S3 + CloudFront へ配信するための**デプロイ経路**を整備。手動スクリプトと
CD（GitHub Actions）ジョブの 2 通りを用意した。いずれも宛先はハードコードせず、
Terraform output / GitHub Variables から取得する。実 `apply`・実デプロイは課金のため未実施。

## 実装
### 手動デプロイ（`scripts/deploy-frontend.ps1`・新規）
- `terraform output` から `frontend_bucket` / `frontend_distribution_id` /
  `frontend_cloudfront_domain` を動的取得（ランダムサフィックス付きバケット名にも追従）。
- 流れ: output 取得 → `npm run build`（未 install なら `npm ci`）→ `aws s3 sync --delete` →
  `aws cloudfront create-invalidation /*` → 公開 URL を表示。
- `-Profile` / `-Region` 引数付き。`$PSScriptRoot` 基準でパス解決し、どこから実行しても動く。

### 自動デプロイ（`.github/workflows/cd.yml` に `deploy-frontend` ジョブ追加）
- push の path フィルタに `frontend/**` を追加。
- Node 20 + `npm ci` + `npm run build`（`VITE_API_BASE_URL` を Variables から注入）。
- OIDC で assume → `aws s3 sync --delete` → CloudFront 無効化。
- 既存 CD と同じく **`vars.AWS_ROLE_ARN` 未設定なら skip**。さらに
  `FRONTEND_BUCKET` / `FRONTEND_DISTRIBUTION_ID` 未設定時もステップ内で安全に skip。

### フロント環境変数
- `frontend/.env.example`（新規）: `VITE_API_BASE_URL` を明示。未設定時は Vite 既定の `/api`。
- `frontend/.gitignore`: `.env` / `.env.*` を除外（`!.env.example` は残す）。実値の誤コミット防止。

### ドキュメント
- `README.md`: 「フロントエンドのデプロイ」節を追加（手動/自動の 2 経路、必要な Variables 一覧、
  ローカル開発は課金なしの注記）。

## 検証エビデンス
- `cd.yml` を YAML パースし、ジョブが `deploy` / `deploy-frontend` の 2 つに増えたことを確認。
- `scripts/deploy-frontend.ps1` を PowerShell パーサで構文チェック = エラーなし。
- **実デプロイ・実 `apply` は未実施**（課金なし）。CD は Variables 未設定のため実運用では skip される状態。

## 運用手順（apply 後に有効化）
1. `cd terraform && terraform apply`
2. output を GitHub の **Variables** に登録:
   - `FRONTEND_BUCKET` = `terraform output -raw frontend_bucket`
   - `FRONTEND_DISTRIBUTION_ID` = `terraform output -raw frontend_distribution_id`
   - （必要なら）`VITE_API_BASE_URL` = 本番 API オリジン
3. 以降 `main` への `frontend/**` 変更 push で自動デプロイ。手動は `./scripts/deploy-frontend.ps1`。

## 学び / 割り切り
- **宛先を output から取得**することで、バケットの再作成やサフィックス変更に強いデプロイにした。
- CD の各段で「未設定なら skip」を徹底し、インフラ未構築の間も安全（誤爆しない）。
- 本番 API オリジン（`VITE_API_BASE_URL`）はビルド時に焼き込まれる Vite の性質上、
  CD のビルドステップで注入する設計にした。

## 次のステップ（候補3: ローカル E2E）
- `docker compose up`（API+DB）+ `npm run dev`（:5173）で、登録→ログイン→タスク CRUD を通しで確認。
- ローカル利用は課金なしなので、使用感の確認・日々使いへ。
