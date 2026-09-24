package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/makotonic999/my-kanban-app/internal/auth"
)

type ctxKey string

// UserIDKey は認証済みユーザーIDを request context に載せる際のキー。
// ハンドラ側は middleware.UserIDFrom(r.Context()) で取得する。
const UserIDKey ctxKey = "userID"

// UserIDFrom は RequireAuth が context に載せた認証済み userID を取り出す。
// 認証を通っていない（キーが無い/型違い）場合は ok=false を返す。
func UserIDFrom(ctx context.Context) (int64, bool) {
	id, ok := ctx.Value(UserIDKey).(int64)
	return id, ok
}

// RequireAuth は "Authorization: Bearer <token>" を検証し、
// 検証済みの userID を context に載せて次のハンドラへ渡す。
// トークンが無い/不正な場合は 401 を返す。
func RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authz := r.Header.Get("Authorization")
		if !strings.HasPrefix(authz, "Bearer ") {
			http.Error(w, "missing bearer token", http.StatusUnauthorized)
			return
		}

		tokenStr := strings.TrimSpace(strings.TrimPrefix(authz, "Bearer "))
		userID, err := auth.ValidateToken(tokenStr)
		if err != nil {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), UserIDKey, userID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
