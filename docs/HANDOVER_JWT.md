# 引継ぎドキュメント - 2026-09-22（JWT認証 着手前）

> 前回（2026-09-16）の続き。フェーズ3の残り #5 JWT認証に着手する直前の引き継ぎ。
> 方針は完全に確定済み。実装コードはまだ未着手（go.mod も未変更）。
> 次回はこのファイルの「実装手順」を上から順にやれば #5 が完了する。

---

## 現在地（2026-09-16 時点から変化なし）

- フェーズ1（DB基礎＋カンバンAPI）: 完了 ✅
- フェーズ2（SRE/観測性: OpenTelemetry・Prometheus・Grafana・SLO）: 完了 ✅
- フェーズ3（API完成・認証・テスト）: 4/7
  - 完了: タスクCRUD / タグモデル / タグCRUD / タスク-タグ関連API（全12エンドポイント実装済み）
  - **未: #5 JWT認証（← 今回これをやる）/ #6 テスト / #7 OpenAPI**

今回のセッションでは「JWT認証の方針決め」と「教育的な現状把握」まで実施。実装は未着手。

---

## #5 JWT認証 — 確定した方針

| 項目 | 決定 |
|---|---|
| ライブラリ | `github.com/golang-jwt/jwt/v5`（デファクト標準） |
| 署名方式 | **HS256**（HMAC-SHA256、共通鍵1個） |
| トークン有効期限 | **24時間**（開発優先。単一アクセストークン） |
| リフレッシュトークン | **なし**（複雑化を避け、まず動くものを完成させる） |
| 保護対象 | タスク系・タグ系エンドポイントすべて |
| 未保護 | `POST /users`（登録）、`POST /login`、`GET /metrics`（Prometheus用） |
| 秘密鍵 | 環境変数 `JWT_SECRET` から読む。**コード/gitに絶対commitしない** |

### 設計メモ（なぜこうするか）
- JWTはステートレス認証。サーバーが「誰がログイン中か」を覚えなくてよい（腕バンド方式）。将来サーバーを複数台にしてもスケールする。
- JWTのPayloadは暗号化されない（Base64なだけ）。**秘密情報は入れない**。守るのは機密性でなく完全性（改ざん検知）。Payloadには user_id と exp のみ。
- HS256は単一サーバー認証で十分。検証を複数サービスに分散したくなったら将来RS256（公開鍵方式）へ。
- bcryptによるパスワード保存は `internal/handler/user.go` の `UserHandler.Create` で実装済み（`password_digest` カラム）。ログインではこのハッシュと照合する。

---

## 既存コードのスタイル（合わせること）

- ルーティング: 標準 `net/http`（Go 1.22+ の `mux.HandleFunc("POST /path/{id}", ...)` 記法）。外部ルータ不使用。
- ハンドラ: 構造体に `DB *sql.DB` を持たせるパターン（例: `type UserHandler struct { DB *sql.DB }`）。
- エラー返却: `http.Error(w, msg, statusCode)`。
- JSON: `json.NewDecoder(r.Body).Decode(&input)` / `json.NewEncoder(w).Encode(v)`。
- モジュールパス: `github.com/makotonic999/my-kanban-app`
- 既存パッケージ: `internal/{handler,model,middleware,db,metrics,telemetry}`

---

## 実装手順（次回はこれを上から順に）

### STEP 0. 環境変数
- `.env` と `.env.example` に `JWT_SECRET` を追加。
  - `.env.example` はダミー値（例: `JWT_SECRET=change-me-in-production`）。
  - `.env` は実値（十分長いランダム文字列）。※ `.env` は .gitignore 済みのはず（要確認）。

### STEP 1. ライブラリ導入
```bash
cd C:\Users\HP\my-kanban-app
go get github.com/golang-jwt/jwt/v5
```

### STEP 2. `internal/auth/jwt.go`（新規）
トークンの発行と検証。雛形：
```go
package auth

import (
	"errors"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func secret() []byte { return []byte(os.Getenv("JWT_SECRET")) }

// GenerateToken は userID を主張(sub)に持つHS256署名JWTを発行する（有効期限24h）。
func GenerateToken(userID int64) (string, error) {
	claims := jwt.MapClaims{
		"sub": userID,
		"exp": time.Now().Add(24 * time.Hour).Unix(),
		"iat": time.Now().Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(secret())
}

// ValidateToken は署名と期限を検証し、userID を返す。
func ValidateToken(tokenString string) (int64, error) {
	token, err := jwt.Parse(tokenString, func(t *jwt.Token) (interface{}, error) {
		// 署名方式がHS256であることを必ず検証（alg混同攻撃対策）
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return secret(), nil
	})
	if err != nil || !token.Valid {
		return 0, errors.New("invalid token")
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return 0, errors.New("invalid claims")
	}
	// JSON数値はfloat64でデコードされる点に注意
	sub, ok := claims["sub"].(float64)
	if !ok {
		return 0, errors.New("invalid sub")
	}
	return int64(sub), nil
}
```
**教育ポイント**: パーサのkeyFuncで `SigningMethodHMAC` を必ずチェックするのは「alg混同攻撃（alg=none や RS256 に差し替える攻撃）」を防ぐため。

### STEP 3. `internal/handler/auth.go`（新規）
`POST /login`。email/passwordを受け、DBからuser取得、bcryptで照合、トークン発行。雛形：
```go
package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/makotonic999/my-kanban-app/internal/auth"
	"golang.org/x/crypto/bcrypt"
)

type AuthHandler struct {
	DB *sql.DB
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	var id int64
	var digest string
	err := h.DB.QueryRow(
		`SELECT id, password_digest FROM users WHERE email = $1`, input.Email,
	).Scan(&id, &digest)
	if err != nil {
		// user不在でも「認証失敗」で統一（emailの存在有無を漏らさない）
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(digest), []byte(input.Password)) != nil {
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}

	token, err := auth.GenerateToken(id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"token": token})
}
```
**教育ポイント**: user不在でもパスワード不一致でも同じ「invalid credentials / 401」を返す＝「そのemailは存在するか」を攻撃者に漏らさない（ユーザー列挙攻撃対策）。
※ users テーブルの列名が `password_digest` であることは user.go のINSERTで確認済み。

### STEP 4. `internal/middleware/auth.go`（新規）
`Authorization: Bearer <token>` を解析→検証→user_idをcontextに載せて次へ。雛形：
```go
package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/makotonic999/my-kanban-app/internal/auth"
)

type ctxKey string

const UserIDKey ctxKey = "userID"

func RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authz := r.Header.Get("Authorization")
		if !strings.HasPrefix(authz, "Bearer ") {
			http.Error(w, "missing bearer token", http.StatusUnauthorized)
			return
		}
		tokenStr := strings.TrimPrefix(authz, "Bearer ")
		userID, err := auth.ValidateToken(tokenStr)
		if err != nil {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}
		ctx := context.WithValue(r.Context(), UserIDKey, userID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
```
**教育ポイント**: 認証済み user_id を context に載せると、各ハンドラが `r.Context().Value(middleware.UserIDKey)` で「今誰か」を取れる。将来「自分のタスクだけ返す」認可に使える。

### STEP 5. `cmd/api/main.go`（修正）
- `authHandler := &handler.AuthHandler{DB: database}` を追加。
- `mux.HandleFunc("POST /login", authHandler.Login)` を登録（未保護でよい）。
- 保護対象（tasks/tags系）に `middleware.RequireAuth` を適用する。
  - **注意**: `RequireAuth` は `http.Handler` を包む形。今の登録は `mux.HandleFunc("GET /tasks", taskHandler.List)` のように直接関数を渡している。
  - 方針案A（シンプル）: 保護対象だけ個別に `mux.Handle("GET /tasks", middleware.RequireAuth(http.HandlerFunc(taskHandler.List)))` と書き換える。
  - 方針案B（まとめて）: 認証必須のルートを別mux（protectedMux）に登録し、それを `RequireAuth` で一括ラップして親muxにマウントする。ただし `net/http` のServeMuxはサブマウントにパスの工夫が要るので、今回は**案Aを推奨**（明示的で分かりやすい）。
  - `POST /users`, `POST /login`, `GET /metrics` は **RequireAuthを付けない**。
- 既存の `middleware.MetricsMiddleware(mux)` のラップはそのまま（全体を計測）。認証はその内側の各ルート単位で効く。

### STEP 6. ビルド・動作確認
```bash
# ビルド
cd C:\Users\HP\my-kanban-app\cmd\api && go build -o app .

# 起動（docker構成の場合）
cd C:\Users\HP\my-kanban-app
docker compose build --no-cache api && docker compose up -d --force-recreate api

# 動作確認フロー
# 1) ユーザー作成
#   POST /users {email, password}
# 2) ログイン → トークン取得
#   POST /login {email, password}  → {"token":"eyJ..."}
# 3) 保護エンドポイントにトークン付きでアクセス（成功）
#   GET /tasks  -H "Authorization: Bearer eyJ..."
# 4) トークン無し/不正でアクセス（401になること）
#   GET /tasks  （ヘッダ無し）→ 401
```
既存の test-*.ps1 を参考に、`test-auth.ps1` を作って上記4フローを自動確認すると良い。

---

## 完了の定義（Doneの基準）
- [ ] `go build` が通る
- [ ] ログイン成功でトークンが返る
- [ ] 正しいトークンで保護エンドポイントにアクセスできる
- [ ] トークン無し/不正だと 401 が返る
- [ ] `JWT_SECRET` は環境変数管理（コード/gitに実値なし）

これが済めばフェーズ3は #6（テスト）#7（OpenAPI）を残すのみ。#5完了でフェーズ4（AWS: ECS Fargate + RDS + ALB, Terraform, CI/CD）へ進める。

---

## 中断の経緯
2026-09-22、JWT実装の方針確定＆現状把握まで完了し、STEP 1（go get）の直前で作業者が外出のため中断。コードは未変更。次回はSTEP 0 or 1から。
