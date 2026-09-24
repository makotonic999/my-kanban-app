# 引継ぎドキュメント - 2026-09-24（フェーズ3 完了）

> 前回（2026-09-22, `HANDOVER_JWT.md`）で確定した方針に沿って、フェーズ3の残タスク
> **#5 JWT認証 / #6 テスト / #7 OpenAPI** を実装・検証し、**フェーズ3を完了**した。

---

## 現在地

- フェーズ1（DB基礎＋カンバンAPI）: 完了 ✅
- フェーズ2（SRE/観測性）: 完了 ✅
- **フェーズ3（API完成・認証・テスト）: 完了 ✅（7/7）**
- フェーズ4以降（AWS配置・フロント・AI・モバイル）: 未着手

---

## #5 JWT認証 — 実装内容

| ファイル | 役割 |
|---|---|
| `internal/auth/jwt.go` | `GenerateToken(userID)` / `ValidateToken(token)`。HS256、有効期限24h（`TokenTTL`）。`ErrEmptySecret` / `ErrInvalidToken`。keyFuncで HMAC を強制し **alg混同攻撃（alg=none / RS256差し替え）を拒否**。 |
| `internal/handler/auth.go` | `AuthHandler.Login`（`POST /login`）。email/password→bcrypt照合→トークン発行。**ユーザー不在もパスワード不一致も同一401**（ユーザー列挙対策）。otelスパン付き。 |
| `internal/middleware/auth.go` | `RequireAuth`。`Authorization: Bearer <token>` を検証し、`UserIDKey` で userID を context に載せる。無/不正トークンは401。 |
| `cmd/api/main.go` | `POST /login` を登録。`protect()` ヘルパでタスク系・タグ系の全ルートを `RequireAuth` でラップ。**未保護**: `POST /users` / `POST /login` / `GET /metrics`。 |

- 依存追加: `github.com/golang-jwt/jwt/v5 v5.3.1`
- 秘密鍵: 環境変数 `JWT_SECRET`。`.env` に64桁hexの実値、`.env.example` にダミー。`.env` は .gitignore 済み。

## #6 テスト — 実装内容

- **ユニット/HTTPテスト（全16件・全PASS）**、`go test ./...` で実行:
  - `internal/auth/jwt_test.go`（8件）: 往復、空secret、失効、鍵違い、改ざん、alg=none拒否、ゴミ入力
  - `internal/middleware/auth_test.go`（4件）: ヘッダ無/不正形式/不正トークンで401、正常トークンで context 伝播＋200
  - `internal/handler/auth_test.go`（4件）: ログイン成功でトークン、誤パスワード401、不明ユーザー401、不正JSON400（`go-sqlmock` 使用）
- 依存追加: `github.com/DATA-DOG/go-sqlmock v1.5.2`
- **統合テスト**: `test-auth.ps1`（登録→ログイン→トークン付き200→トークン無401→不正トークン401→誤パスワード401 の6フロー）を作成。
  - ⚠️ **未実行のブロッカー**: 本セッションでは **Docker デーモンが起動しておらず**、live統合テストを実行できなかった。スクリプトは準備済み。
    Docker Desktop 起動後、`docker compose up -d` → `./test-auth.ps1` で確認すること。
    （なお同じ401/成功パスは `httptest` ベースのユニットテストで検証済み。）

## #7 OpenAPI — 実装内容

- `docs/openapi.yaml`（OpenAPI 3.0.3）。**11パス / 9スキーマ**。
- `securitySchemes.bearerAuth`（http/bearer/JWT）をグローバルに適用し、`/users` `/login` `/metrics` は `security: []` で上書き。
- well-formed YAML であることを検証済み（一時Goバリデータ→ `YAML_OK openapi=3.0.3 paths=11 schemas=9`。検証後クリーンアップし、yaml は直接依存に残していない）。

---

## 検証エビデンス（本セッション実施）

- `go build ./...` → `BUILD_OK`
- `go test ./...` → auth / handler / middleware すべて `ok`（16テストPASS）
- `go.mod` 直接依存は `go-sqlmock` と `golang-jwt/jwt/v5` のみ（`go mod tidy` 済み）

## 未確認 / 残課題

- [ ] `test-auth.ps1` の live 実行（Docker起動後）
- [ ] 認可（現状は「認証」のみ。将来 context の userID を使い「自分のタスクだけ」へ絞る認可を追加可能）
- [ ] リフレッシュトークン（現状なし、単一24hアクセストークン）

---

## 次のステップ（フェーズ4：AWS配置 & インフラ）

- インフラ構成（ECS Fargate + RDS PostgreSQL + ALB）
- IaC（Terraform または AWS CDK）
- CI/CDパイプライン（GitHub Actions）
- 本番へのSRE設定反映（Prometheus / Grafana / SLO）

> 注: フェーズ4は実AWSアカウント操作・課金が絡むため、環境準備（アカウント/認証情報/リージョン方針）を決めてから着手するのが安全。
