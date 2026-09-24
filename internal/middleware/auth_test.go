package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/makotonic999/my-kanban-app/internal/auth"
)

const testSecret = "test-secret-for-middleware-tests-abcdef0123"

// okHandler は認証を通過したときに context から userID を読んで200で返す。
func okHandler(t *testing.T, wantID int64) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got, ok := r.Context().Value(UserIDKey).(int64)
		if !ok {
			t.Errorf("userID not found in context")
			http.Error(w, "no userID", http.StatusInternalServerError)
			return
		}
		if got != wantID {
			t.Errorf("context userID = %d, want %d", got, wantID)
		}
		w.WriteHeader(http.StatusOK)
	})
}

func TestRequireAuth_NoHeader(t *testing.T) {
	t.Setenv("JWT_SECRET", testSecret)

	h := RequireAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("handler should not be called without a token")
	}))

	req := httptest.NewRequest(http.MethodGet, "/tasks", nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestRequireAuth_MalformedHeader(t *testing.T) {
	t.Setenv("JWT_SECRET", testSecret)

	h := RequireAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("handler should not be called with malformed header")
	}))

	req := httptest.NewRequest(http.MethodGet, "/tasks", nil)
	req.Header.Set("Authorization", "Token abc") // "Bearer " 前置きでない
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestRequireAuth_InvalidToken(t *testing.T) {
	t.Setenv("JWT_SECRET", testSecret)

	h := RequireAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("handler should not be called with invalid token")
	}))

	req := httptest.NewRequest(http.MethodGet, "/tasks", nil)
	req.Header.Set("Authorization", "Bearer not.a.valid.jwt")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestRequireAuth_ValidToken(t *testing.T) {
	t.Setenv("JWT_SECRET", testSecret)

	const wantID int64 = 123
	tok, err := auth.GenerateToken(wantID)
	if err != nil {
		t.Fatalf("GenerateToken error: %v", err)
	}

	h := RequireAuth(okHandler(t, wantID))

	req := httptest.NewRequest(http.MethodGet, "/tasks", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}
