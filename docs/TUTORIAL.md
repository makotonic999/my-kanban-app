# プロダクト理解チュートリアル — my-kanban-app

このドキュメントは、本プロジェクトを**フロントエンドからインフラ・DBまで一気通貫で理解する**ための
チュートリアルです。「バイブコーディングで動くものはできたが、構造を腹落ちさせたい」という目的に向け、
**アーキテクチャの全体像 → 各層の詳細 → データの流れ**の順で、実コードを参照しながら解説します。

読む順番は上から下で構いません。まず 0〜2 章で地図を持ち、3 章以降で各層に降りていきます。

---

## 目次

0. [このアプリは何か（30秒サマリー）](#0-このアプリは何か)
1. [アーキテクチャ全体像 ★最重要](#1-アーキテクチャ全体像-最重要)
2. [1本のリクエストが辿る道（データフロー）★最重要](#2-1本のリクエストが辿る道)
3. [フロントエンド層](#3-フロントエンド層)
4. [バックエンド層（Go API）](#4-バックエンド層-go-api)
5. [認証・認可（セキュリティの心臓部）★重点](#5-認証認可)
6. [データベース層](#6-データベース層)
7. [オブザーバビリティ層（SRE）](#7-オブザーバビリティ層)
8. [インフラ層（ローカル / AWS）★重点](#8-インフラ層)
9. [CI/CD](#9-cicd)
10. [3環境の分離という設計思想 ★重点](#10-3環境の分離という設計思想)
11. [用語集](#用語集)

★=アーキテクチャ理解の核。ここを重点的に。

---

## 0. このアプリは何か

個人用のカンバンボード（To Do / In Progress / Done の3列でタスク管理）。
最終目標は「1年分のタスクログを AI が分析して振り返りを返す」こと。そのため今は
「使ってデータを貯める」段階にある。

技術スタックを一言で:
- **フロント**: React + TypeScript + Vite + Tailwind CSS
- **バックエンド**: Go（標準ライブラリの `net/http` 中心）+ PostgreSQL
- **インフラ**: ローカルは Docker Compose、AWS は Terraform（ECS Fargate + RDS + ALB / S3 + CloudFront）
- **SRE**: OpenTelemetry（トレース）+ Prometheus/Grafana（メトリクス）
- **CI/CD**: GitHub Actions（OIDC でシークレットレス）

---

## 1. アーキテクチャ全体像 ★最重要

### 1.1 レイヤー構造

このアプリは古典的な**3層アーキテクチャ**（プレゼンテーション / アプリケーション / データ）に、
横断的関心事（認証・監視）をミドルウェアで挟む構成になっている。

```
┌─────────────────────────────────────────────────────────┐
│  プレゼンテーション層  (frontend/)                        │
│  React コンポーネント（Login / Board / TaskCard）         │
│      │  fetch() で JSON をやりとり                        │
│      ▼                                                    │
│  api.ts（HTTPクライアント。JWTをヘッダに付与）            │
└──────────────────────────┬──────────────────────────────┘
                           │ HTTP (JSON, Bearer トークン)
                           ▼
┌─────────────────────────────────────────────────────────┐
│  アプリケーション層  (cmd/api + internal/)               │
│                                                           │
│  ミドルウェア連鎖（外側から順に適用）:                    │
│    CORS → Metrics → [ルーティング] → RequireAuth → Handler│
│                                                           │
│  ハンドラ（handler/）: リクエストを解釈し DB を操作       │
│  認証（auth/）: JWT の発行・検証                          │
└──────────────────────────┬──────────────────────────────┘
                           │ database/sql (DSN)
                           ▼
┌─────────────────────────────────────────────────────────┐
│  データ層  (PostgreSQL)                                   │
│  users / tasks / tags / task_tags / task_status_events    │
└─────────────────────────────────────────────────────────┘
```

### 1.2 ディレクトリと責務の対応

| ディレクトリ | 層 | 責務 |
|---|---|---|
| `frontend/src/` | プレゼンテーション | UI・画面・HTTPクライアント |
| `cmd/api/main.go` | 起動 | 依存の組み立て（DI）・ルーティング・ミドルウェア合成 |
| `internal/handler/` | アプリケーション | HTTP ハンドラ（タスク/タグ/認証/ユーザー） |
| `internal/middleware/` | 横断 | 認証・CORS・メトリクス |
| `internal/auth/` | ドメイン | JWT 発行・検証 |
| `internal/model/` | ドメイン | データ構造（Go struct） |
| `internal/db/` | インフラ | DB 接続 |
| `internal/metrics/` `internal/telemetry/` | 横断（SRE） | メトリクス定義・トレース初期化 |
| `db/init.sql` | データ | スキーマ定義 |
| `terraform/` | インフラ | AWS リソース定義（IaC） |
| `.github/workflows/` | CI/CD | 自動テスト・デプロイ |

### 1.3 設計上の重要な考え方（ここが腹落ちすると全体が見える）

1. **`main.go` が「配線盤」**。DB接続・各ハンドラ・ミドルウェアを組み立てて `http.Server` に渡す。
   依存性注入（DI）を手書きでやっている。フレームワーク非依存で、標準ライブラリだけで構成。
2. **ミドルウェアは「玉ねぎ」**。リクエストは外側の層（CORS）から入り、内側（Handler）へ進み、
   レスポンスは逆順で出ていく。各層は「次のハンドラ」を受け取り、前後に処理を挟む関数。
3. **認可の真実はトークン**。「誰のデータか」はリクエストボディを信じず、JWTから取り出した userID で決める。
4. **コードは1つ、環境は設定で分ける**。ローカルとAWSで同じGoバイナリ・同じReactコードが動く。
   違いは環境変数（`DATABASE_URL` / `JWT_SECRET` / `CORS_ALLOWED_ORIGINS` / `VITE_API_BASE_URL`）だけ。

---

## 2. 1本のリクエストが辿る道 ★最重要

抽象論より、具体的な1リクエストを追う方が構造が掴める。
**「ログイン済みユーザーがタスクを1件作る」**を例に、端から端まで辿る。

### 2.1 フロント側（ボタンを押してから）

1. ユーザーがタスク作成フォームで「追加」を押す（`Board.tsx` の `handleCreate`）。
2. `api.ts` の `createTask()` が呼ばれる。
3. `request()` が組み立てる:
   - URL: `BASE_URL + "/tasks"`（`BASE_URL` は開発では `/api`、本番は `VITE_API_BASE_URL`）
   - ヘッダ: `Content-Type: application/json` と `Authorization: Bearer <保存済みトークン>`
   - ボディ: `{"title": "...", "due_date": "..."}`
4. `fetch()` で送信。開発では Vite の dev proxy が `/api/tasks` → `http://api:8080/tasks` に転送する
   （`vite.config.ts` の proxy 設定。`/api` プレフィックスは rewrite で除去）。

### 2.2 バックエンド側（ミドルウェアの玉ねぎを通る）

リクエストは `main.go` で組んだミドルウェア連鎖を通る。外側から順に:

```
リクエスト
  → CORS          （middleware/cors.go）   Origin検査・OPTIONS即応答
  → Metrics       （middleware/metrics.go） 開始時刻を記録・レスポンスを計測
  → ServeMux      （main.go）               "POST /tasks" にマッチ → ルート決定
  → RequireAuth   （middleware/auth.go）    Bearerトークン検証 → userIDをcontextに載せる
  → TaskHandler.Create（handler/task.go）   本体処理
```

ポイント: `main.go` を見ると、`/tasks` は `protect(taskHandler.Create)` で包まれている。
`protect` は `RequireAuth` でラップするヘルパー。一方 `/login` `/users` は包まれていない（未認証で叩ける）。
つまり「どのルートが認証必須か」は `main.go` のルーティング定義を見れば一目で分かる。

### 2.3 ハンドラ本体（`TaskHandler.Create`）

1. `middleware.UserIDFrom(ctx)` で、RequireAuth が context に載せた userID を取り出す。
   → **ここが認可の要**。ボディに `user_id:999` を混ぜても無視し、トークンの userID で作成する。
2. トランザクションを開始（`BeginTx`）。
3. `INSERT INTO tasks (...) RETURNING *` でタスクを作成。
4. `INSERT INTO task_status_events (task_id, NULL, 'todo')` で初回の状態遷移を記録。
5. `Commit()`。どちらかが失敗すれば `Rollback()` で両方巻き戻る（原子性）。
6. `201 Created` と作成したタスクの JSON を返す。

### 2.4 レスポンスが戻る（玉ねぎを逆順で）

```
Handler がレスポンス書き込み
  → Metrics が経過時間・ステータス・サイズを記録（http_requests_total など）
  → CORS は素通り
  → フロントの fetch が JSON を受け取る
  → Board.tsx が refresh() でタスク一覧を再取得 → 画面更新
```

この2章の流れが理解できれば、他のエンドポイント（更新・削除・完了・タグ）もすべて同じ骨格で読める。

---

## 3. フロントエンド層

`frontend/` 配下。React 18 + TypeScript + Vite + Tailwind CSS。

### 3.1 エントリと構造

- `index.html` → `src/main.tsx`（React を DOM にマウント）→ `App.tsx`
- `App.tsx`: 認証状態で分岐。未ログインなら `<Login>`、ログイン済みなら `<Board>` + ヘッダ/フッタ。
- `components/Login.tsx`: ログイン/新規登録フォーム。
- `components/Board.tsx`: カンバン本体（3列・カードCRUD・キーボード操作・インライン編集）。
- `components/ShortcutsHelp.tsx`: `?` キーで開くショートカット一覧モーダル。

### 3.2 状態管理と API 通信

- 状態管理ライブラリは使わず、React の `useState` / `useEffect` のみ（規模的に十分）。
- API 通信は `src/api.ts` に集約。`request<T>()` が「ベースURL付与・JWTヘッダ付与・エラーを `ApiError` に変換」を
  一手に引き受ける。各関数（`login` / `listTasks` / `createTask` / `updateTask` ...）はその薄いラッパー。
- **トークンの保管**: `localStorage`（キー `kanban_token`）。`getToken` / `setToken` / `clearToken`。
- **401 の扱い**: `request()` が 401 を `ApiError` として投げ、UI 側でログアウト（`onUnauthorized`）に繋げる。

### 3.3 型定義（`src/types.ts`）

Go の `model.Task` と対応する TypeScript 型を持つ。バックエンドの JSON 構造とフロントの型が
1:1 で対応しているのが読みどころ（`due_date` `estimated_minutes` などは null 許容）。

### 3.4 キーボード操作の設計

- キー割り当ての「案内」は `src/keymap.ts` に集約（将来ユーザーがカスタマイズできる布石）。
- 実ハンドリングは `Board.tsx` の `useEffect` 内 `window.addEventListener("keydown", ...)`。
- 選択カーソル `{col, row}` を state で持ち、矢印で移動、Shift+矢印でステータス移動、F2 でインライン編集。

### 3.5 ビルドと開発サーバー

- `npm run dev` = Vite dev server（ホットリロード、`:5173`）。
- `npm run build` = `tsc --noEmit`（型チェック）+ `vite build`（本番バンドル）。
- 開発時は dev proxy で CORS を回避、本番は `VITE_API_BASE_URL` で API オリジンを直接指定。

---

## 4. バックエンド層（Go API）

`cmd/api/main.go` + `internal/`。Web フレームワークを使わず、Go 1.22+ の `net/http` の
拡張ルーティング（`"POST /tasks"` のようなメソッド+パス指定）を使う。

### 4.1 起動シーケンス（`cmd/api/main.go`）

`main()` は「配線」を上から順に行う:

1. `.env` を読む（無くてもOK。本番は環境変数を直接使う）。
2. テレメトリ初期化（`telemetry.NewTracerProvider`）。
3. DB 接続（`db.New(DATABASE_URL)`）。
4. 各ハンドラを生成（`TaskHandler` `UserHandler` `TagHandler` `AuthHandler`。いずれも `DB` を注入）。
5. `http.NewServeMux()` にルートを登録。認証必須ルートは `protect()`（= `RequireAuth`）で包む。
6. ミドルウェアを合成: `CORS(MetricsMiddleware(mux))`。
7. `http.ListenAndServe(":8080", handler)`。

この関数を読むだけで「エンドポイント一覧」「どれが認証必須か」「ミドルウェアの順序」が全部分かる。
**まず main.go を読め**、が本プロジェクトの理解の近道。

### 4.2 ハンドラ（`internal/handler/`）

- `task.go`: タスクの List / GetByID / Create / Update / Delete / Complete / AddTag / RemoveTag。
- `auth.go`: Login（email/password → bcrypt照合 → JWT発行）。
- `user.go`: Create（ユーザー登録）。
- `tag.go`: タグの CRUD。

ハンドラの共通パターン:
1. パスパラメータ取得（`r.PathValue("id")`）。
2. `UserIDFrom(ctx)` で認証済み userID を取得。
3. リクエストボディを struct にデコード。
4. SQL を実行（`WHERE ... AND user_id = $N` で必ず所有者に絞る）。
5. JSON を返す。

### 4.3 モデル（`internal/model/`）

DB の行と対応する Go の struct。`Task` / `User` / `Tag` / `TaskStatusEvent`。
null 許容カラムは `*string` `*time.Time` `*int` のようにポインタで表現する（DBの NULL と対応）。

### 4.4 DB 接続（`internal/db/db.go`）

`sql.Open("postgres", dsn)` + `Ping()` だけの薄いラッパー。
接続プールは `database/sql` が内部で管理。ドライバは `lib/pq`。

---

## 5. 認証・認可 ★重点

「壊れると被害が大きい」領域。ここは特に丁寧に理解しておく。

### 5.1 認証と認可の違い（まず用語）

- **認証 (Authentication)**: 「あなたは誰か」を確かめる。→ ログイン、JWT 検証。
- **認可 (Authorization)**: 「その操作をしてよいか」を確かめる。→ 自分のタスクだけ操作可能。

### 5.2 JWT の発行と検証（`internal/auth/jwt.go`）

- 方式は **HS256**（HMAC-SHA256、共通鍵1個）。有効期限24時間。
- 署名鍵は環境変数 `JWT_SECRET`（コード/gitに置かない）。
- `GenerateToken(userID)`: `sub`（userID）・`exp`・`iat` を claim に入れて署名。
- `ValidateToken(token)`: 署名と期限を検証し userID を返す。
  - **alg混同攻撃対策**: `keyFunc` で「署名方式が HMAC であること」を必ず確認する。
    これをやらないと、攻撃者が `alg=none` や公開鍵を悪用した RS256 に差し替える攻撃が通ってしまう。

### 5.3 ログインの流れ（`internal/handler/auth.go`）

1. email でユーザーを検索。
2. `bcrypt.CompareHashAndPassword` でパスワード照合。
3. 一致すれば `GenerateToken` で JWT を発行して返す。
- **ユーザー列挙対策**: 「ユーザー不在」でも「パスワード不一致」でも、区別せず同じ `401 invalid credentials` を返す。
  これで「そのメールアドレスは登録済みか」を攻撃者に漏らさない。

### 5.4 認証ミドルウェア（`internal/middleware/auth.go`）

- `RequireAuth(next)` は `Authorization: Bearer <token>` を検証し、成功したら
  `context.WithValue(ctx, UserIDKey, userID)` で userID を context に載せて次へ渡す。
- 失敗（トークン無し/不正）は即 `401`。
- ハンドラは `UserIDFrom(ctx)` でこの userID を受け取る。
- **context を「認証済みユーザーの受け渡し口」に使う**のが Go の定石。ハンドラの引数を汚さずに伝播できる。

### 5.5 認可の実装（source of truth はトークン）

- **作成**: 所有者はボディではなく `UserIDFrom(ctx)` の userID を使う（なりすまし防止）。
- **一覧/取得/更新/削除**: SQL に必ず `AND user_id = $N` を付ける。
- **他人のリソースは 404**（403 ではなく）。「その ID は存在するが権限がない」と「存在しない」を区別させず、
  ID の存在推測を防ぐ。

### 5.6 テストで守っている不変条件（`internal/handler/*_test.go`, `internal/auth/*_test.go`）

- JWT の改ざん / 失効 / alg混同 を拒否する（8件）。
- ログインの bcrypt 照合・列挙対策・入力検証（4件）。
- 認可: 自分のタスクのみ操作・他人は404・作成は本人ID（6件）。
- ミドルウェア + context 伝播（5件）。
- `go-sqlmock` で DB をモックし、SQL に `user_id` が正しく渡ることまで検証している。

---

## 6. データベース層

PostgreSQL 16。スキーマ定義は `db/init.sql`、テーブル定義書は `docs/db/`。

### 6.1 テーブルとリレーション

```
users (1) ──< (N) tasks (N) >──< (M) tags        （N:M は task_tags で中間テーブル）
                   │
                   └──< (N) task_status_events    （タスクの状態遷移履歴）
```

- `users`: ユーザー（email 一意、password_digest は bcrypt ハッシュ）。
- `tasks`: タスク（user_id で所有者、status/due_date/estimated_minutes/completed_at など）。
- `tags` / `task_tags`: タグと、タスク⇄タグの N:M 関連（複合主キー、`ON DELETE CASCADE`）。
- `task_status_events`: **状態遷移の履歴**（後述。フェーズ6の下ごしらえ）。

### 6.2 インデックス設計

`user_id` / `status` / `due_date` / `completed_at` に B-Tree インデックス。
「ユーザーごとに絞る」「ステータスで絞る」「期日順に並べる」といった典型クエリを速くするため。

### 6.3 状態遷移履歴（`task_status_events`）— 設計の勘所

- タスクの status が変わるたびに1行記録する（`from_status` → `to_status` + `changed_at`）。
- 記録タイミング: 作成時（`NULL → todo`）/ Update で status 変化時 / Complete（`→ done`）。
- **原子性**: tasks の更新と履歴の INSERT を**同一トランザクション**で行う（片方だけ成功する事故を防ぐ）。
- **正確な from の取得**: 更新前に `SELECT status ... FOR UPDATE` で行ロックして現在値を読む。
- **誤記録防止**: status が実際に変わった時だけ記録（タイトルだけの更新では記録しない）。
- 狙い: リードタイム（作成→完了）、サイクルタイム（着手→完了）、差し戻し回数などを後で集計し、
  AI 年間振り返りの素材にする。「手入力の見積もり」より「自動で貯まる客観ログ」を選んだ、という判断の産物。

### 6.4 マイグレーションの運用（重要な注意）

- **自動マイグレーションの仕組みはまだ無い**。スキーマは手動運用。
- 新規 DB は `db/init.sql` が初期スキーマ。既存の稼働中 DB へは手動で `ALTER`/`CREATE TABLE IF NOT EXISTS` を流す。
- つまりスキーマ変更時は「init.sql 更新」＋「稼働 DB へ手動適用」の**両建て**が必要。
- 将来 AWS 本番 RDS に載せる時も、この移行手順を明示的に実行する必要がある（将来の改善候補）。

---

## 7. オブザーバビリティ層（SRE）

「動いているか」だけでなく「どう動いているか」を計測する仕組み。ローカルでは監視オーバーレイ
（`docker-compose.observability.yml`）を重ねた時だけ有効になる。

### 7.1 トレース（OpenTelemetry → Jaeger）

- `internal/telemetry/tracer.go` が TracerProvider を初期化し、OTLP(HTTP) で Jaeger に送信。
- ハンドラや DB クエリで `otel.Tracer("...").Start(ctx, "span名")` を張り、処理の内訳を可視化。
- 送信先は環境変数 `OTEL_EXPORTER_OTLP_ENDPOINT`。未設定（空）ならローカルのコア構成では送らない。
- Jaeger UI（`:16686`）で「1リクエストの中で DB クエリに何 ms かかったか」などが追える。

### 7.2 メトリクス（Prometheus → Grafana）

- `internal/metrics/metrics.go` が Prometheus のメトリクスを定義:
  - `http_request_duration_seconds`（レイテンシのヒストグラム。p95/p99 算出用）
  - `http_requests_total`（リクエスト数カウンタ）
  - `http_request_size_bytes` / `http_response_size_bytes`
  - `db_query_duration_seconds` / `db_queries_total`
- `internal/middleware/metrics.go` が全リクエストを計測し、`ResponseWriter` をラップして
  ステータスコード・レスポンスサイズをキャプチャする。
- `/metrics` エンドポイントで Prometheus 形式を公開（`main.go` で `promhttp.Handler()` を登録）。
- Prometheus（`:9090`）がスクレイプ、Grafana（`:3000`）で可視化。

### 7.3 SLO

- `docs/SLO.md` に SLO（サービスレベル目標）とエラー予算の考え方。
- `slo_rules.yml` / `alert_rules.yml` に記録ルール・アラートルール。
- AWS 版は AMP（Amazon Managed Prometheus）+ Amazon Managed Grafana + ADOT sidecar で同等を実現
  （`terraform/amp.tf` `grafana.tf` `adot.tf`、ADR は `docs/adr/0001-...`）。

---

## 8. インフラ層 ★重点

**同じアプリを2つの方法で動かす**。ローカル（Docker Compose）と AWS（Terraform）。

### 8.1 ローカル（Docker Compose）

- `docker-compose.yml`（コア）: `db`（Postgres）+ `api`（Go）+ `frontend`（Vite）の3サービス。
- `docker-compose.observability.yml`（監視）: `jaeger` + `prometheus` + `grafana`。見たい時だけ `-f` で重ねる。
- 全サービスに `restart: unless-stopped` → Docker Desktop 起動時に自動復帰（フル自動化）。
- データは名前付きボリューム `postgres_data` に永続化 → 停止・シャットダウンでも消えない。
- サービス間通信は compose のネットワークでサービス名解決（フロントは `api:8080` を見る）。

`api` の Dockerfile（マルチステージビルド）:
1. Build stage: `golang:1.27-alpine` でバイナリをビルド（`CGO_ENABLED=0` で静的リンク）。
2. Runtime stage: `alpine` にバイナリだけコピー。イメージが小さく安全。

### 8.2 AWS（Terraform）— `terraform/`

本番構成（`terraform apply` は課金のため未適用。`plan` は通過済み）。

ネットワーク（`network.tf`）:
- VPC + public/private サブネット（複数AZ）。
- NAT Gateway は **デフォルト無効**（`enable_nat_gateway`）。無効時は Fargate を public サブネットに置いて
  パブリックIPを付与し、コストを抑える。有効時は private + NAT。この**トグル設計**がコスト意識の表れ。

コンピュート（`ecs.tf`）:
- ECS Fargate（サーバーレスコンテナ）。タスク定義に **api コンテナ + ADOT collector sidecar**。
- 機密（`DATABASE_URL` / `JWT_SECRET`）は環境変数直書きせず **SSM Parameter Store から実行時注入**。
- ログは CloudWatch Logs へ。

データベース（`rds.tf`）:
- RDS PostgreSQL（Single-AZ 最小構成）。
- マスターパスワードは Terraform の `random_password` で生成 → SSM に SecureString で保存。
- アプリ用 `DATABASE_URL`（DSN）も組み立てて SSM に保存し、ECS から参照。

ロードバランサ（`alb.tf`）:
- ALB（public サブネット）→ ターゲットグループ（Fargate の IP ターゲット）。
- ヘルスチェックは `/metrics`（認証不要で 200 を返すため流用）。

フロント配信（`frontend_hosting.tf`）:
- S3（静的ホスティング）+ CloudFront（CDN）。

**ローカルと AWS の対応関係**（これが分かると「1コード2環境」が腹落ちする）:

| 要素 | ローカル | AWS |
|---|---|---|
| フロント配信 | Vite dev server (compose) | S3 + CloudFront |
| API 実行 | api コンテナ (compose) | ECS Fargate |
| DB | Postgres コンテナ (compose) | RDS |
| ルーティング/入口 | compose network | ALB |
| 機密 | compose の環境変数 / `.env` | SSM Parameter Store |
| 監視 | jaeger/prometheus/grafana (compose) | AMP + Managed Grafana + ADOT |

Go のコードも React のコードも**まったく同じ**。違うのは「どこで動かすか」と「環境変数」だけ。

---

## 9. CI/CD

`.github/workflows/`。GitHub Actions。

### 9.1 CI（`ci.yml`）— push / PR で自動実行

2ジョブが走る:
- **Go build & test**: gofmt チェック → `go vet` → `go build` → `go test -race -cover`。
- **Terraform checks**: `fmt -check` → `init -backend=false` → `validate`（AWS 不要・課金なし）。

補足（実運用での学び）: `pull_request` の CI は「PRブランチを main にマージした結果」を検証するため、
`push` では通っても `pull_request` で落ちることがある（例: main 側に gofmt 違反が混ざっていた場合）。
gofmt はコンパイルではなく整形スタイルのチェックなので、build/test が通っても別途落ちうる。

### 9.2 CD（`cd.yml`）— `main` push で AWS へ

- **OIDC（シークレットレス）**: 長期の AWS アクセスキーを持たず、GitHub の OIDC で IAM ロールを一時 assume。
  信頼ポリシーは当該リポジトリの `main`/タグに限定（`terraform/oidc_github.tf`）。
- 流れ: OIDC で assume → Docker イメージを ECR に push → ECS タスク定義を更新してサービスをローリング更新。
- フロントは `frontend/**` 変更時に S3 同期 + CloudFront 無効化。
- リポジトリ Variables（`AWS_ROLE_ARN` など）が未設定なら安全に skip する（apply 前でも壊れない）。

---

## 10. 3環境の分離という設計思想 ★重点

このプロジェクトの背骨となる思想。**環境はブランチで分けない。コードは1つ、設定で分ける。**

| 環境 | 目的 | 分け方 |
|---|---|---|
| 1. ローカル | 日々使う・データ蓄積 | `docker-compose.yml` |
| 2. AWS 版 | Web 公開 | `terraform/` |
| 3. モバイル版 | 将来 Google Play | 別リポジトリ（フェーズ7） |

- 1 と 2 は**同じソース**。違いは設定（compose vs terraform）と環境変数のみ。
- なぜブランチで分けないか: 環境ごとにブランチを切るとコードが乖離し、片方だけ直す・マージ地獄になる
  （典型的アンチパターン）。設定で分ければ本体コードは常に1つ。
- モバイルだけ別リポジトリなのは、言語・ツールチェーン・リリースサイクルが Web と根本的に違うため。
  ただしバックエンド（AWS 版 API / RDS）は Web と共用する。

**開発は Vite プロキシ、本番は CORS の二本立て**もこの思想の具体例:
- ローカル: フロントは Vite proxy 経由で API を叩くのでブラウザから見て同一オリジン → CORS 不要。
- 本番: フロント（CloudFront）と API（ALB）でオリジンが異なる → サーバ側 CORS が必須。
- だから CORS ミドルウェアは常に用意しつつ、許可オリジンを環境変数 `CORS_ALLOWED_ORIGINS` で切り替える。

---

## 用語集

| 用語 | 意味 |
|---|---|
| DI（依存性注入） | 依存オブジェクト（DB接続など）を外から渡すこと。ここでは `main.go` が手書きで注入。 |
| ミドルウェア | ハンドラの前後に共通処理を挟む仕組み。`func(next) http.Handler` の形。 |
| JWT | JSON Web Token。署名付きの認証トークン。ここでは HS256。 |
| bcrypt | パスワードハッシュ関数。総当たりに強い。 |
| CORS | 異なるオリジン間の HTTP アクセス制御。ブラウザのセキュリティ機構。 |
| DSN | データベース接続文字列（`host=... user=...`）。 |
| IaC | Infrastructure as Code。インフラをコードで定義（Terraform）。 |
| Fargate | サーバー管理不要でコンテナを動かす AWS のサービス。 |
| OIDC | OpenID Connect。ここでは GitHub↔AWS の鍵レス認証に使用。 |
| SLO | Service Level Objective。サービス品質の目標値。 |
| リードタイム/サイクルタイム | 作成→完了 / 着手→完了 にかかった時間。生産性の指標。 |

---

## 次に読むと理解が深まるもの

- `cmd/api/main.go` — まずこれ。全体の配線が1ファイルで分かる。
- `internal/handler/task.go` の `Create`/`Update`/`Complete` — トランザクションと状態遷移記録の実例。
- `internal/middleware/auth.go` + `internal/auth/jwt.go` — 認証の全体。
- `docs/learning/2026-09-24-jwt-auth-flow.md` — JWT 認証フローの詳しい解説。
- `docs/dev-log/` — 各機能が「なぜそう作られたか」の時系列の軌跡。
- `docs/openapi.yaml` — API の入出力仕様（全エンドポイント）。
