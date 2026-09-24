package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"golang.org/x/crypto/bcrypt"
)

func mustHash(t *testing.T, password string) string {
	t.Helper()
	h, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		t.Fatalf("bcrypt hash error: %v", err)
	}
	return string(h)
}

func TestLogin_Success(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret-for-login-handler-0123456789")

	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock.New error: %v", err)
	}
	defer db.Close()

	digest := mustHash(t, "correct-password")
	rows := sqlmock.NewRows([]string{"id", "password_digest"}).AddRow(int64(7), digest)
	mock.ExpectQuery("SELECT id, password_digest FROM users WHERE email").
		WithArgs("user@example.com").
		WillReturnRows(rows)

	h := &AuthHandler{DB: db}
	body := `{"email":"user@example.com","password":"correct-password"}`
	req := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader(body))
	rec := httptest.NewRecorder()

	h.Login(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}

	var resp map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("response is not valid JSON: %v", err)
	}
	if resp["token"] == "" {
		t.Fatal("expected a non-empty token in response")
	}
}

func TestLogin_WrongPassword(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret-for-login-handler-0123456789")

	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock.New error: %v", err)
	}
	defer db.Close()

	digest := mustHash(t, "correct-password")
	rows := sqlmock.NewRows([]string{"id", "password_digest"}).AddRow(int64(7), digest)
	mock.ExpectQuery("SELECT id, password_digest FROM users WHERE email").
		WithArgs("user@example.com").
		WillReturnRows(rows)

	h := &AuthHandler{DB: db}
	body := `{"email":"user@example.com","password":"wrong-password"}`
	req := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader(body))
	rec := httptest.NewRecorder()

	h.Login(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestLogin_UnknownUser(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret-for-login-handler-0123456789")

	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock.New error: %v", err)
	}
	defer db.Close()

	// ユーザー不在 → ErrNoRows 相当（行を返さない）。
	mock.ExpectQuery("SELECT id, password_digest FROM users WHERE email").
		WithArgs("ghost@example.com").
		WillReturnError(sqlmock.ErrCancelled) // 何らかのエラーでも401で統一されること

	h := &AuthHandler{DB: db}
	body := `{"email":"ghost@example.com","password":"whatever"}`
	req := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader(body))
	rec := httptest.NewRecorder()

	h.Login(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401 (must not leak user existence)", rec.Code)
	}
}

func TestLogin_BadJSON(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret-for-login-handler-0123456789")

	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock.New error: %v", err)
	}
	defer db.Close()

	h := &AuthHandler{DB: db}
	req := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader("{not json"))
	rec := httptest.NewRecorder()

	h.Login(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}
