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
	if err := godotenv.Load(); err != nil {
		log.Fatal("Error loading .env file")
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

	mux := http.NewServeMux()
	mux.HandleFunc("POST /users", userHandler.Create)
	mux.HandleFunc("GET /tasks", taskHandler.List)
	mux.HandleFunc("POST /tasks", taskHandler.Create)
	mux.HandleFunc("GET /tasks/{id}", taskHandler.GetByID)
	mux.HandleFunc("PATCH /tasks/{id}", taskHandler.Update)
	mux.HandleFunc("DELETE /tasks/{id}", taskHandler.Delete)
	mux.HandleFunc("PATCH /tasks/{id}/complete", taskHandler.Complete)
	mux.HandleFunc("POST /tasks/{id}/tags", taskHandler.AddTag)
	mux.HandleFunc("DELETE /tasks/{id}/tags/{tag_id}", taskHandler.RemoveTag)
	mux.HandleFunc("GET /users/{user_id}/tags", tagHandler.List)
	mux.HandleFunc("POST /tags", tagHandler.Create)
	mux.HandleFunc("DELETE /tags/{id}", tagHandler.Delete)
	// Prometheusがメトリクスを収集するエンドポイント
	mux.Handle("GET /metrics", promhttp.Handler())

	// メトリクスミドルウェアを適用
	handlerWithMetrics := middleware.MetricsMiddleware(mux)

	fmt.Println("Server running on :8080")
	log.Fatal(http.ListenAndServe(":8080", handlerWithMetrics))
}
