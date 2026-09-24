package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/makotonic999/my-kanban-app/internal/auth"
)

type ctxKey string

// UserIDKey は認証済みユーザーIDを request context に載せる際のキー。
// ハンドラ側は r.Context().Value(middleware.UserIDKey).(int64) で取得できる。
const UserIDKey ctxKey = "userID"

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
