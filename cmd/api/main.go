package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/joho/godotenv"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/makotonic999/my-kanban-app/internal/db"
	"github.com/makotonic999/my-kanban-app/internal/handler"
	"github.com/makotonic999/my-kanban-app/internal/middleware"
	"github.com/makotonic999/my-kanban-app/internal/telemetry"
)

func main() {
	// .env はローカル開発時のみ存在する。ECS などでは環境変数（SSM 由来）を直接使うため、
	// ファイルが無くても致命的エラーにしない。
	if err := godotenv.Load(); err != nil {
		log.Println("no .env file loaded; using process environment variables")
	}

	ctx := context.Background()
	tp, err := telemetry.NewTracerProvider(ctx, os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"))
	if err != nil {
		log.Fatal(err)
	}
	defer tp.Shutdown(ctx)

	dsn := os.Getenv("DATABASE_URL")
	database := db.New(dsn)
	defer database.Close()

	taskHandler := &handler.TaskHandler{DB: database}
	userHandler := &handler.UserHandler{DB: database}
	tagHandler := &handler.TagHandler{DB: database}
	authHandler := &handler.AuthHandler{DB: database}

	mux := http.NewServeMux()

	// protect は保護対象ルートを RequireAuth で包むためのヘルパー。
	// http.HandlerFunc を http.Handler に変換してミドルウェアでラップする。
	protect := func(h http.HandlerFunc) http.Handler {
		return middleware.RequireAuth(http.HandlerFunc(h))
	}

	// --- 未保護エンドポイント（登録・ログイン・メトリクス） ---
	mux.HandleFunc("POST /users", userHandler.Create)
	mux.HandleFunc("POST /login", authHandler.Login)
	// Prometheusがメトリクスを収集するエンドポイント
	mux.Handle("GET /metrics", promhttp.Handler())

	// --- 保護対象エンドポイント（要 Bearer トークン） ---
	mux.Handle("GET /tasks", protect(taskHandler.List))
	mux.Handle("POST /tasks", protect(taskHandler.Create))
	mux.Handle("GET /tasks/{id}", protect(taskHandler.GetByID))
	mux.Handle("PATCH /tasks/{id}", protect(taskHandler.Update))
	mux.Handle("DELETE /tasks/{id}", protect(taskHandler.Delete))
	mux.Handle("PATCH /tasks/{id}/complete", protect(taskHandler.Complete))
	mux.Handle("POST /tasks/{id}/tags", protect(taskHandler.AddTag))
	mux.Handle("DELETE /tasks/{id}/tags/{tag_id}", protect(taskHandler.RemoveTag))
	mux.Handle("GET /tags", protect(tagHandler.List))
	mux.Handle("POST /tags", protect(tagHandler.Create))
	mux.Handle("DELETE /tags/{id}", protect(tagHandler.Delete))

	// メトリクスミドルウェアを適用
	handlerWithMetrics := middleware.MetricsMiddleware(mux)

	fmt.Println("Server running on :8080")
	log.Fatal(http.ListenAndServe(":8080", handlerWithMetrics))
}
