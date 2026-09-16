package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// HTTPRequestDuration は HTTP リクエストのレイテンシを測定するヒストグラム
// バケット: 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 2.5s, 5s, 10s
var HTTPRequestDuration = promauto.NewHistogramVec(
	prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "Duration of HTTP requests in seconds",
		Buckets: prometheus.DefBuckets, // [.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10]
	},
	[]string{"method", "path", "status"},
)

// HTTPRequestTotal は HTTP リクエストの総数
var HTTPRequestTotal = promauto.NewCounterVec(
	prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total number of HTTP requests",
	},
	[]string{"method", "path", "status"},
)

// HTTPRequestSize はリクエストボディサイズをバイト単位で測定
var HTTPRequestSize = promauto.NewHistogramVec(
	prometheus.HistogramOpts{
		Name:    "http_request_size_bytes",
		Help:    "Size of HTTP requests in bytes",
		Buckets: prometheus.ExponentialBuckets(100, 2, 8), // 100, 200, 400, ..., 12800 bytes
	},
	[]string{"method", "path"},
)

// HTTPResponseSize はレスポンスボディサイズをバイト単位で測定
var HTTPResponseSize = promauto.NewHistogramVec(
	prometheus.HistogramOpts{
		Name:    "http_response_size_bytes",
		Help:    "Size of HTTP responses in bytes",
		Buckets: prometheus.ExponentialBuckets(100, 2, 8),
	},
	[]string{"method", "path", "status"},
)

// DatabaseQueryDuration はデータベースクエリのレイテンシを測定
var DatabaseQueryDuration = promauto.NewHistogramVec(
	prometheus.HistogramOpts{
		Name:    "db_query_duration_seconds",
		Help:    "Duration of database queries in seconds",
		Buckets: prometheus.DefBuckets,
	},
	[]string{"operation", "table"},
)

// DatabaseQueryTotal はデータベースクエリの総数
var DatabaseQueryTotal = promauto.NewCounterVec(
	prometheus.CounterOpts{
		Name: "db_queries_total",
		Help: "Total number of database queries",
	},
	[]string{"operation", "table", "status"},
)
