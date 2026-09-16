package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/makotonic999/my-kanban-app/internal/model"
	"golang.org/x/crypto/bcrypt"
)

type UserHandler struct {
	DB *sql.DB
}

func (h *UserHandler) Create(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Email       string  `json:"email"`
		Password    string  `json:"password"`
		DisplayName *string `json:"display_name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var u model.User
	err = h.DB.QueryRow(
		`INSERT INTO users (email, password_digest, display_name) VALUES ($1, $2, $3) RETURNING id, email, display_name, created_at, updated_at`,
		input.Email, string(hash), input.DisplayName,
	).Scan(&u.ID, &u.Email, &u.DisplayName, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(u)
}
