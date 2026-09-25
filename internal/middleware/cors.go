package middleware

import (
	"net/http"
	"os"
	"strings"
)

// allowedOrigins は CORS で許可するオリジンの集合を環境変数から取得する。
// CORS_ALLOWED_ORIGINS はカンマ区切り（例: "http://localhost:5173,https://example.com"）。
// 未設定時はローカル開発の Vite オリジンを既定で許可する。
func allowedOrigins() map[string]bool {
	raw := os.Getenv("CORS_ALLOWED_ORIGINS")
	if raw == "" {
		raw = "http://localhost:5173,http://127.0.0.1:5173"
	}
	set := make(map[string]bool)
	for _, o := range strings.Split(raw, ",") {
		if o = strings.TrimSpace(o); o != "" {
			set[o] = true
		}
	}
	return set
}

// CORS は許可オリジンからのクロスオリジン要求に必要なヘッダを付与し、
// OPTIONS プリフライトに応答するミドルウェア。
//
// 本番では CloudFront のオリジンと API のオリジンが異なるため CORS が必須になる。
// 開発では Vite プロキシ経由なら同一オリジン扱いになるが、直接アクセスに備えて用意する。
func CORS(next http.Handler) http.Handler {
	origins := allowedOrigins()
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && origins[origin] {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			// オリジンごとにレスポンスが変わることをキャッシュに伝える。
			w.Header().Add("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
			w.Header().Set("Access-Control-Max-Age", "3600")
		}

		// プリフライト（OPTIONS）はここで完了させる。
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}
