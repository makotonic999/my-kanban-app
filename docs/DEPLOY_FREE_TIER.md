# 無料枠での Web 公開手順（Cloudflare Pages + Render + Neon）

このアプリを **月額 $0** を狙って Web 公開するための手順。
3 つのサービスに「フロント / API / DB」を間借りし、環境変数で配線する。

```
Cloudflare Pages ── フロント（静的）     VITE_API_BASE_URL → Render の API URL
        │
Render ─────────── API（Go/Docker）      DATABASE_URL → Neon の接続文字列
        │                                 CORS_ALLOWED_ORIGINS → Cloudflare の URL
Neon ───────────── DB（PostgreSQL）
```

- リポジトリは分けない。3 サービスとも同じ `makotonic999/my-kanban-app` の main を見る。
- コードは変更不要。違いは各サービスに設定する**環境変数だけ**。
- 進める順番は **Neon → Render → Cloudflare**（後のサービスが前のサービスの URL を必要とするため）。

> 無料枠の内容は変わりやすい。作業前に各サービスの料金ページで最新を確認すること。
> 想定挙動: Render 無料は 15 分アイドルでスリープ→次アクセスの起動に約 1 分（コールドスタート）。

---

## 事前準備
- GitHub アカウント（リポジトリ `makotonic999/my-kanban-app` が push 済み）。
- （任意）ローカルに `psql` があるとスキーマ適用が楽。無ければ Neon の SQL エディタを使う。

---

## STEP 1: Neon（DB）

### 1-1. プロジェクト作成
1. https://neon.com にサインアップ（GitHub ログイン可）。
2. 新規プロジェクトを作成。リージョンは可能なら近い場所（例: アジア）を選ぶ。
3. Postgres バージョンは既定でよい。

### 1-2. 接続文字列を取得
1. プロジェクトの「Connection string」をコピーする。
   形式: `postgresql://<user>:<password>@<host>/<db>?sslmode=require`
2. これを後で Render の `DATABASE_URL` に使う。**sslmode=require が含まれていること**を確認。

### 1-3. スキーマを適用
このリポジトリの [`db/schema.sql`](../db/schema.sql) を Neon に 1 回流す（冪等なので再実行も安全）。

- 方法A（psql がある場合）:
  ```bash
  psql "postgresql://...（Neon の接続文字列）..." -f db/schema.sql
  ```
- 方法B（Neon の SQL エディタ）:
  `db/schema.sql` の中身を全部コピーして、Neon のダッシュボードの SQL エディタに貼り付けて実行。

適用後、テーブル（users / tasks / tags / task_tags / task_status_events）が作成される。

---

## STEP 2: Render（API）

### 2-1. Blueprint でサービス作成
1. https://render.com にサインアップ（GitHub ログイン可）。
2. New → **Blueprint** → リポジトリ `makotonic999/my-kanban-app` を選択。
3. リポジトリ直下の [`render.yaml`](../render.yaml) が検出され、`my-kanban-api`（Docker・free）が作られる。

### 2-2. 環境変数を設定（`render.yaml` で sync:false のもの）
作成時またはダッシュボードの Environment で入力する:

| 変数 | 値 |
|---|---|
| `DATABASE_URL` | STEP 1-2 の Neon 接続文字列（`sslmode=require` 込み） |
| `JWT_SECRET` | 十分に長いランダム文字列（Render の Generate でも可） |
| `CORS_ALLOWED_ORIGINS` | STEP 3 で確定する Cloudflare の URL（**まず仮で空 or 後で設定**） |

- `PORT` は Render が自動注入する（アプリは対応済み。手動設定不要）。
- `OTEL_EXPORTER_OTLP_ENDPOINT` は空のまま（監視基盤は未接続）。

### 2-3. デプロイと確認
1. デプロイが走る（Dockerfile からビルド）。完了すると API の URL が発行される。
   例: `https://my-kanban-api.onrender.com`
2. 動作確認: ブラウザか curl で `https://<API_URL>/metrics` を開く → Prometheus 形式のテキストが返れば OK。
   （初回はコールドスタートで ~1 分かかることがある）
3. この API URL を STEP 3 の `VITE_API_BASE_URL` に使う。

---

## STEP 3: Cloudflare Pages（フロント）

### 3-1. プロジェクト作成
1. https://dash.cloudflare.com → Workers & Pages → Pages → リポジトリ連携で
   `makotonic999/my-kanban-app` を選択。

### 3-2. ビルド設定
| 項目 | 値 |
|---|---|
| Production branch | `main` |
| Framework preset | None（または Vite） |
| Build command | `npm run build` |
| Build output directory | `dist` |
| Root directory | `frontend` |

> フロントはサブディレクトリ `frontend/` にあるので **Root directory を `frontend` にする**のが重要。
> ビルド成果物は `frontend/dist` に出る。

### 3-3. 環境変数（ビルド時）
| 変数 | 値 |
|---|---|
| `VITE_API_BASE_URL` | STEP 2-3 の Render の API URL（例 `https://my-kanban-api.onrender.com`） |

> `VITE_` 接頭辞の変数はビルド時にバンドルへ埋め込まれる。設定後に再デプロイすると反映される。

### 3-4. デプロイ
デプロイ完了で Cloudflare の URL が発行される。例: `https://my-kanban-app.pages.dev`

---

## STEP 4: 配線の仕上げ（CORS）

フロントの URL が確定したので、API 側に「このオリジンを許可」と教える:

1. Render の `my-kanban-api` → Environment → `CORS_ALLOWED_ORIGINS` に
   Cloudflare の URL を設定（例: `https://my-kanban-app.pages.dev`）。
   - 複数許可する場合はカンマ区切り（独自ドメインを足す時など）。
2. 保存すると Render が再デプロイされる。

---

## STEP 5: 動作確認（本番）

1. Cloudflare の URL をブラウザで開く。
2. サインアップ → サインイン → タスク作成 → ステータス移動 まで通ることを確認。
   - 初回アクセスは Render のコールドスタートで数十秒待つことがある。
3. スマホのブラウザでも同じ URL でアクセスできる（レスポンシブ最適化は今後の課題）。

---

## トラブルシュート

| 症状 | 原因 / 対処 |
|---|---|
| フロントで API エラー / CORS エラー | `CORS_ALLOWED_ORIGINS`（Render）が Cloudflare の URL と**完全一致**しているか。末尾スラッシュ・http/https の違いに注意 |
| ログインで 500 や接続エラー | `DATABASE_URL`（Render）が正しいか、`sslmode=require` 込みか。Neon のコールドスタート中は数秒待つ（起動時リトライ実装済み） |
| API が起動しない | Render のログを確認。`DATABASE_URL` 未設定だと DB 接続リトライ後に落ちる |
| フロントが真っ白 / 404 | Cloudflare の Root directory=`frontend`、Build output=`dist` を確認 |
| タスクが保存されない | Neon にスキーマ（`db/schema.sql`）を適用済みか確認 |

---

## コストと運用メモ
- 3 サービスとも無料プランの範囲内なら月 $0。低トラフィックの個人利用を想定。
- Render 無料はスリープあり → 常時即応が必要になったら有料（$7/月〜）に上げるとスリープ無効。
- データの持ち出し: Neon は標準 Postgres なので `pg_dump` でいつでもエクスポート可能（ロックインが弱い）。
- 独自ドメインを使う場合: Cloudflare Pages にカスタムドメインを設定し、
  その URL を Render の `CORS_ALLOWED_ORIGINS` にも追加する。
- マイグレーション: 自動適用の仕組みは無い。スキーマ変更時は `db/schema.sql` を更新し、Neon に再適用する。
