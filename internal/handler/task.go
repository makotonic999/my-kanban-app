package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
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

func (h *TaskHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("task").Start(r.Context(), "GetByID")
	defer span.End()

	id := r.PathValue("id")
	if id == "" {
		http.Error(w, "missing id parameter", http.StatusBadRequest)
		return
	}

	_, dbSpan := otel.Tracer("task").Start(ctx, "db.query: SELECT task by id")
	var t model.Task
	err := h.DB.QueryRowContext(ctx,
		`SELECT id, user_id, title, description, status, due_date, estimated_minutes, actual_minutes, completed_at, created_at, updated_at FROM tasks WHERE id = $1`,
		id,
	).Scan(&t.ID, &t.UserID, &t.Title, &t.Description, &t.Status, &t.DueDate, &t.EstimatedMinutes, &t.ActualMinutes, &t.CompletedAt, &t.CreatedAt, &t.UpdatedAt)
	dbSpan.End()
	if err == sql.ErrNoRows {
		http.Error(w, "task not found", http.StatusNotFound)
		return
	}
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(t)
}

func (h *TaskHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("task").Start(r.Context(), "Create")
	defer span.End()

	var input struct {
		UserID           int64  `json:"user_id"`
		Title            string `json:"title"`
		Description      *string `json:"description"`
		EstimatedMinutes *int   `json:"estimated_minutes"`
		DueDate          *time.Time `json:"due_date"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	_, dbSpan := otel.Tracer("task").Start(ctx, "db.query: INSERT tasks")
	var t model.Task
	err := h.DB.QueryRowContext(ctx,
		`INSERT INTO tasks (user_id, title, description, estimated_minutes, due_date) VALUES ($1, $2, $3, $4, $5) RETURNING id, user_id, title, description, status, due_date, estimated_minutes, actual_minutes, completed_at, created_at, updated_at`,
		input.UserID, input.Title, input.Description, input.EstimatedMinutes, input.DueDate,
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

func (h *TaskHandler) Update(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("task").Start(r.Context(), "Update")
	defer span.End()

	id := r.PathValue("id")
	if id == "" {
		http.Error(w, "missing id parameter", http.StatusBadRequest)
		return
	}

	var input struct {
		Title            *string `json:"title"`
		Description      *string `json:"description"`
		Status           *string `json:"status"`
		DueDate          *time.Time `json:"due_date"`
		EstimatedMinutes *int   `json:"estimated_minutes"`
		ActualMinutes    *int   `json:"actual_minutes"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// 更新カラムの動的構築
	query := `UPDATE tasks SET updated_at = NOW()`
	args := []interface{}{}
	argIndex := 1

	if input.Title != nil {
		query += `, title = $` + strconv.Itoa(argIndex)
		args = append(args, *input.Title)
		argIndex++
	}
	if input.Description != nil {
		query += `, description = $` + strconv.Itoa(argIndex)
		args = append(args, *input.Description)
		argIndex++
	}
	if input.Status != nil {
		query += `, status = $` + strconv.Itoa(argIndex)
		args = append(args, *input.Status)
		argIndex++
	}
	if input.DueDate != nil {
		query += `, due_date = $` + strconv.Itoa(argIndex)
		args = append(args, *input.DueDate)
		argIndex++
	}
	if input.EstimatedMinutes != nil {
		query += `, estimated_minutes = $` + strconv.Itoa(argIndex)
		args = append(args, *input.EstimatedMinutes)
		argIndex++
	}
	if input.ActualMinutes != nil {
		query += `, actual_minutes = $` + strconv.Itoa(argIndex)
		args = append(args, *input.ActualMinutes)
		argIndex++
	}

	query += ` WHERE id = $` + strconv.Itoa(argIndex)
	args = append(args, id)
	query += ` RETURNING id, user_id, title, description, status, due_date, estimated_minutes, actual_minutes, completed_at, created_at, updated_at`

	_, dbSpan := otel.Tracer("task").Start(ctx, "db.query: UPDATE tasks")
	var t model.Task
	err := h.DB.QueryRowContext(ctx, query, args...).Scan(&t.ID, &t.UserID, &t.Title, &t.Description, &t.Status, &t.DueDate, &t.EstimatedMinutes, &t.ActualMinutes, &t.CompletedAt, &t.CreatedAt, &t.UpdatedAt)
	dbSpan.End()
	if err == sql.ErrNoRows {
		http.Error(w, "task not found", http.StatusNotFound)
		return
	}
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(t)
}

func (h *TaskHandler) Delete(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("task").Start(r.Context(), "Delete")
	defer span.End()

	id := r.PathValue("id")
	if id == "" {
		http.Error(w, "missing id parameter", http.StatusBadRequest)
		return
	}

	_, dbSpan := otel.Tracer("task").Start(ctx, "db.query: DELETE tasks")
	result, err := h.DB.ExecContext(ctx, `DELETE FROM tasks WHERE id = $1`, id)
	dbSpan.End()
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if rowsAffected == 0 {
		http.Error(w, "task not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
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

func (h *TaskHandler) AddTag(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("task").Start(r.Context(), "AddTag")
	defer span.End()

	taskID := r.PathValue("id")
	if taskID == "" {
		http.Error(w, "missing id parameter", http.StatusBadRequest)
		return
	}

	var input struct {
		TagID int64 `json:"tag_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	_, dbSpan := otel.Tracer("task").Start(ctx, "db.query: INSERT task_tags")
	_, err := h.DB.ExecContext(ctx,
		`INSERT INTO task_tags (task_id, tag_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		taskID, input.TagID,
	)
	dbSpan.End()
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *TaskHandler) RemoveTag(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("task").Start(r.Context(), "RemoveTag")
	defer span.End()

	taskID := r.PathValue("id")
	tagID := r.PathValue("tag_id")
	if taskID == "" || tagID == "" {
		http.Error(w, "missing id or tag_id parameter", http.StatusBadRequest)
		return
	}

	_, dbSpan := otel.Tracer("task").Start(ctx, "db.query: DELETE task_tags")
	result, err := h.DB.ExecContext(ctx,
		`DELETE FROM task_tags WHERE task_id = $1 AND tag_id = $2`,
		taskID, tagID,
	)
	dbSpan.End()
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if rowsAffected == 0 {
		http.Error(w, "task or tag not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
