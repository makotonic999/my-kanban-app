# 引継ぎドキュメント - 2026-09-16

## 本日の進捗

### ✅ 完了したこと

**フェーズ2：SRE & オブザーバビリティ（完結）**
- [x] OpenTelemetry トレーシング
- [x] Prometheus メトリクス可視化
- [x] SLO / エラー予算の定義・監視・アラート
- [x] Grafana ダッシュボードの自動プロビジョニング

**フェーズ3：API完成の進捗（4/7 タスク完了）**
- [x] #1 タスク CRUD 完成（GET by ID、PATCH update、DELETE）
- [x] #2 タグ関連モデル作成（Tag、TagHandler）
- [x] #3 タグ CRUD（GET、POST、DELETE）
- [x] #4 タスク-タグ関連API（タグ追加・削除）

### 📊 API エンドポイント完成度

全12エンドポイント実装済み：
- `POST /users` — ユーザー作成
- `GET/POST /tasks` — タスク一覧・作成
- `GET/PATCH/DELETE /tasks/{id}` — タスク取得・更新・削除
- `PATCH /tasks/{id}/complete` — タスク完了
- `POST/DELETE /tasks/{id}/tags` — タスクにタグ追加・削除
- `GET /users/{user_id}/tags` — ユーザーのタグ一覧
- `POST/DELETE /tags` — タグ作成・削除

---

## 次のステップ（フェーズ3 残り）

### #5 JWT認証実装（最優先）

**実装内容**
- `internal/auth/jwt.go` — JWT 署名・検証ロジック
- `internal/handler/auth.go` — ログインエンドポイント（`POST /login`）
- `internal/middleware/auth.go` — JWT 認証ミドルウェア
- `cmd/api/main.go` — ミドルウェアをルートに適用

**チェックリスト**
- [ ] ユーザーのパスワード検証（bcrypt）
- [ ] JWT トークン発行（HS256署名）
- [ ] トークン検証ミドルウェア
- [ ] `Authorization: Bearer {token}` ヘッダー解析
- [ ] テスト：ログイン → トークン取得 → 保護されたエンドポイントアクセス

**ヒント**
- 既に `UserHandler.Create` で bcrypt ハッシュ化を実装済み
- JWT ライブラリ: `github.com/golang-jwt/jwt/v5` 等を使用
- secret key は環境変数 `JWT_SECRET` から読み込む

---

### #6 ユニットテスト・統合テスト

**テスト対象**
- ハンドラーの入出力（unit tests）
- DB操作の整合性（integration tests with testcontainers）
- 認証フロー（e2e-like tests）

**テスト記述場所**
- `internal/handler/*_test.go`
- `internal/db/*_test.go`

---

### #7 OpenAPI/Swagger ドキュメント

**方法**
- swag ツール使用（`go install github.com/swaggo/swag/cmd/swag@latest`）
- ハンドラーにコメント記述 → `swag init -g cmd/api/main.go` で自動生成
- `/swagger/index.html` で確認可能

---

## 関連ファイル一覧

### 新規作成ファイル（本日）
- `slo_rules.yml` — Recording Rules
- `alert_rules.yml` — Alerting Rules
- `grafana/provisioning/datasources/prometheus.yml`
- `grafana/provisioning/dashboards/dashboards.yml`
- `internal/model/tag.go`
- `internal/handler/tag.go`
- `test-crud-simple.ps1`
- `test-tag-crud.ps1`
- `test-task-tag.ps1`

### 修正ファイル（本日）
- `README.md` — ロードマップ再整理、フェーズ3進捗更新
- `prometheus.yml` — rule_files 追加
- `docker-compose.yml` — prometheus / grafana にボリュームマウント追加
- `cmd/api/main.go` — 新エンドポイント登録
- `internal/handler/task.go` — GetByID / Update / Delete / AddTag / RemoveTag メソッド追加
- `docs/SLO.md` — 新規作成

---

## 開発時のトラブルシューティング

### Docker イメージが更新されない場合
```bash
docker compose build --no-cache api
docker compose up -d --force-recreate api
```

### DB スキーマの確認
```bash
docker exec my-kanban-app-db-1 psql -U kanban -d kanban_dev -c "\dt"
```

### メトリクス・SLO の確認
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)
- Jaeger: http://localhost:16686

---

## 環境構成

### サービス稼働状況
```bash
docker compose ps
```

### ローカル開発時のビルド・実行
```bash
cd cmd/api
go build -o app .
./app
```

### 依存パッケージ
- `github.com/lib/pq` — PostgreSQL ドライバー
- `go.opentelemetry.io/*` — トレーシング
- `github.com/prometheus/client_golang` — メトリクス
- `golang.org/x/crypto/bcrypt` — パスワードハッシュ
- `github.com/joho/godotenv` — 環境変数読み込み

---

## 次回作業の優先度

1. **高** — JWT認証実装（#5）→ フェーズ3がほぼ完結する
2. **中** — テスト実装（#6）→ コード品質保証
3. **中** — OpenAPI ドキュメント（#7）→ API 仕様の外部共有用

JWT認証が完了すれば、フェーズ4（AWS配置）に進める準備完了です。

---

## 関連コマンド

```bash
# API ビルド・起動
cd cmd/api && go build -o app . && docker compose build --no-cache api && docker compose up -d --force-recreate api

# DB 接続
docker exec -it my-kanban-app-db-1 psql -U kanban -d kanban_dev

# ログ確認
docker compose logs api -f
docker compose logs prometheus -f
docker compose logs grafana -f

# Git 履歴確認
git log --oneline | head -10
