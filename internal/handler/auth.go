package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/codes"
	"golang.org/x/crypto/bcrypt"

	"github.com/makotonic999/my-kanban-app/internal/auth"
)

type AuthHandler struct {
	DB *sql.DB
}

// Login は email/password を受け取り、bcryptで照合してJWTを発行する。
//
// セキュリティ上、ユーザー不在でもパスワード不一致でも同じ "invalid credentials / 401"
// を返す。これは「そのemailは登録済みか」を攻撃者に漏らさないため（ユーザー列挙対策）。
func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	ctx, span := otel.Tracer("auth").Start(r.Context(), "Login")
	defer span.End()

	var input struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	_, dbSpan := otel.Tracer("auth").Start(ctx, "db.query: SELECT user by email")
	var id int64
	var digest string
	err := h.DB.QueryRowContext(ctx,
		`SELECT id, password_digest FROM users WHERE email = $1`, input.Email,
	).Scan(&id, &digest)
	dbSpan.End()
	if err != nil {
		// sql.ErrNoRows も含め、原因を区別せず401で統一。
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}

	if bcrypt.CompareHashAndPassword([]byte(digest), []byte(input.Password)) != nil {
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}

	token, err := auth.GenerateToken(id)
	if err != nil {
		span.SetStatus(codes.Error, err.Error())
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"token": token})
}
