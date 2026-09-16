package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/codes"

	"github.com/makotonic999/my-kanban-app/internal/model"
)

type TaskHandler struct {
	DB *sql.DB
}

func (h *TaskHandler) List(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("task").Start(r.Context(), "List")
	defer span.End()

	// DBクエリのスパンを開始
	_, dbSpan := otel.Tracer("task").Start(ctx, "db.query: SELECT tasks")
	rows, err := h.DB.QueryContext(ctx, `SELECT id, user_id, title, description, status, due_date, estimated_minutes, actual_minutes, completed_at, created_at, updated_at FROM tasks ORDER BY created_at DESC`)
	dbSpan.End()
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	tasks := []model.Task{}
	for rows.Next() {
		var t model.Task
		if err := rows.Scan(&t.ID, &t.UserID, &t.Title, &t.Description, &t.Status, &t.DueDate, &t.EstimatedMinutes, &t.ActualMinutes, &t.CompletedAt, &t.CreatedAt, &t.UpdatedAt); err != nil {
			span.SetStatus(codes.Error, err.Error())
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		tasks = append(tasks, t)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tasks)
}

func (h *TaskHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("task").Start(r.Context(), "Create")
	defer span.End()

	var input struct {
		UserID           int64  `json:"user_id"`
		Title            string `json:"title"`
		EstimatedMinutes *int   `json:"estimated_minutes"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	_, dbSpan := otel.Tracer("task").Start(ctx, "db.query: INSERT tasks")
	var t model.Task
	err := h.DB.QueryRowContext(ctx,
		`INSERT INTO tasks (user_id, title, estimated_minutes) VALUES ($1, $2, $3) RETURNING id, user_id, title, description, status, due_date, estimated_minutes, actual_minutes, completed_at, created_at, updated_at`,
		input.UserID, input.Title, input.EstimatedMinutes,
	).Scan(&t.ID, &t.UserID, &t.Title, &t.Description, &t.Status, &t.DueDate, &t.EstimatedMinutes, &t.ActualMinutes, &t.CompletedAt, &t.CreatedAt, &t.UpdatedAt)
	dbSpan.End()
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(t)
}

func (h *TaskHandler) Complete(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("task").Start(r.Context(), "Complete")
	defer span.End()

	id := r.PathValue("id")
	now := time.Now()

	_, dbSpan := otel.Tracer("task").Start(ctx, "db.query: UPDATE tasks")
	var t model.Task
	err := h.DB.QueryRowContext(ctx,
		`UPDATE tasks SET status = 'done', completed_at = $1, updated_at = NOW() WHERE id = $2 RETURNING id, user_id, title, description, status, due_date, estimated_minutes, actual_minutes, completed_at, created_at, updated_at`,
		now, id,
	).Scan(&t.ID, &t.UserID, &t.Title, &t.Description, &t.Status, &t.DueDate, &t.EstimatedMinutes, &t.ActualMinutes, &t.CompletedAt, &t.CreatedAt, &t.UpdatedAt)
	dbSpan.End()
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(t)
}
