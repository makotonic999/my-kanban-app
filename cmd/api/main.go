package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/joho/godotenv"
	"github.com/makotonic999/my-kanban-app/internal/db"
	"github.com/makotonic999/my-kanban-app/internal/handler"
	"github.com/makotonic999/my-kanban-app/internal/telemetry"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Fatal("Error loading .env file")
	}

	// トレーサーを初期化してJaegerに接続
	ctx := context.Background()
	tp, err := telemetry.NewTracerProvider(ctx, os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"))
	if err != nil {
		log.Fatal(err)
	}
	// アプリ終了時にトレースを全部送信してから閉じる
	defer tp.Shutdown(ctx)

	dsn := os.Getenv("DATABASE_URL")
	database := db.New(dsn)
	defer database.Close()

	taskHandler := &handler.TaskHandler{DB: database}
	userHandler := &handler.UserHandler{DB: database}

	mux := http.NewServeMux()
	mux.HandleFunc("POST /users", userHandler.Create)
	mux.HandleFunc("GET /tasks", taskHandler.List)
	mux.HandleFunc("POST /tasks", taskHandler.Create)
	mux.HandleFunc("PATCH /tasks/{id}/complete", taskHandler.Complete)

	fmt.Println("Server running on :8080")
	log.Fatal(http.ListenAndServe(":8080", mux))
}
