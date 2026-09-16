package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/codes"

	"github.com/makotonic999/my-kanban-app/internal/model"
)

type TagHandler struct {
	DB *sql.DB
}

func (h *TagHandler) List(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("tag").Start(r.Context(), "List")
	defer span.End()

	userID := r.PathValue("user_id")
	if userID == "" {
		http.Error(w, "missing user_id parameter", http.StatusBadRequest)
		return
	}

	_, dbSpan := otel.Tracer("tag").Start(ctx, "db.query: SELECT tags")
	rows, err := h.DB.QueryContext(ctx,
		`SELECT id, user_id, name, created_at FROM tags WHERE user_id = $1 ORDER BY name`,
		userID,
	)
	dbSpan.End()
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	tags := []model.Tag{}
	for rows.Next() {
		var t model.Tag
		if err := rows.Scan(&t.ID, &t.UserID, &t.Name, &t.CreatedAt); err != nil {
			span.SetStatus(codes.Error, err.Error())
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		tags = append(tags, t)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tags)
}

func (h *TagHandler) Create(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("tag").Start(r.Context(), "Create")
	defer span.End()

	var input struct {
		UserID int64  `json:"user_id"`
		Name   string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if input.Name == "" {
		http.Error(w, "name is required", http.StatusBadRequest)
		return
	}

	_, dbSpan := otel.Tracer("tag").Start(ctx, "db.query: INSERT tags")
	var t model.Tag
	err := h.DB.QueryRowContext(ctx,
		`INSERT INTO tags (user_id, name) VALUES ($1, $2) RETURNING id, user_id, name, created_at`,
		input.UserID, input.Name,
	).Scan(&t.ID, &t.UserID, &t.Name, &t.CreatedAt)
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

func (h *TagHandler) Delete(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("tag").Start(r.Context(), "Delete")
	defer span.End()

	id := r.PathValue("id")
	if id == "" {
		http.Error(w, "missing id parameter", http.StatusBadRequest)
		return
	}

	_, dbSpan := otel.Tracer("tag").Start(ctx, "db.query: DELETE tags")
	result, err := h.DB.ExecContext(ctx, `DELETE FROM tags WHERE id = $1`, id)
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
		http.Error(w, "tag not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
