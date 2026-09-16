package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/joho/godotenv"
	"github.com/makotonic999/my-kanban-app/internal/db"
	"github.com/makotonic999/my-kanban-app/internal/handler"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Fatal("Error loading .env file")
	}
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
