package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/makotonic999/my-kanban-app/internal/db"
	"github.com/makotonic999/my-kanban-app/internal/handler"
)

func main() {
	dsn := "host=localhost port=5432 user=kanban password=kanban dbname=kanban_dev sslmode=disable"
	database := db.New(dsn)
	defer database.Close()

	h := &handler.TaskHandler{DB: database}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /tasks", h.List)
	mux.HandleFunc("POST /tasks", h.Create)
	mux.HandleFunc("PATCH /tasks/{id}/complete", h.Complete)

	fmt.Println("Server running on :8080")
	log.Fatal(http.ListenAndServe(":8080", mux))
}
