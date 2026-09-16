package middleware

import (
	"net/http"
	"strconv"
	"time"

	"github.com/makotonic999/my-kanban-app/internal/metrics"
)

// MetricsMiddleware は HTTP レクエストのメトリクスを計測するミドルウェア
func MetricsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// ResponseWriter をラップしてステータスコードとレスポンスサイズをキャプチャ
		wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

		// ハンドラーを実行
		next.ServeHTTP(wrapped, r)

		// メトリクスを記録
		duration := time.Since(start).Seconds()
		statusStr := strconv.Itoa(wrapped.statusCode)

		metrics.HTTPRequestDuration.WithLabelValues(
			r.Method,
			r.URL.Path,
			statusStr,
		).Observe(duration)

		metrics.HTTPRequestTotal.WithLabelValues(
			r.Method,
			r.URL.Path,
			statusStr,
		).Inc()

		if wrapped.responseSize > 0 {
			metrics.HTTPResponseSize.WithLabelValues(
				r.Method,
				r.URL.Path,
				statusStr,
			).Observe(float64(wrapped.responseSize))
		}

		if r.ContentLength > 0 {
			metrics.HTTPRequestSize.WithLabelValues(
				r.Method,
				r.URL.Path,
			).Observe(float64(r.ContentLength))
		}
	})
}

// responseWriter は http.ResponseWriter をラップしてステータスコードとレスポンスサイズをキャプチャ
type responseWriter struct {
	http.ResponseWriter
	statusCode   int
	responseSize int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func (rw *responseWriter) Write(b []byte) (int, error) {
	rw.responseSize += len(b)
	return rw.ResponseWriter.Write(b)
}
