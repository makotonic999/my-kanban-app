package handler

import (
	"context"
	"database/sql"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"

	"github.com/makotonic999/my-kanban-app/internal/middleware"
)

// withUser は認証済み userID を context に載せた *http.Request を返す。
// RequireAuth を通した後のハンドラの状態を再現する。
func withUser(req *http.Request, userID int64) *http.Request {
	ctx := context.WithValue(req.Context(), middleware.UserIDKey, userID)
	return req.WithContext(ctx)
}

func newTaskRows() *sqlmock.Rows {
	return sqlmock.NewRows([]string{
		"id", "user_id", "title", "description", "status", "due_date",
		"estimated_minutes", "actual_minutes", "completed_at", "created_at", "updated_at",
	})
}

// List は「自分の userID」でDBを絞り込むこと（他人のタスクを返さない）。
func TestTaskList_ScopedToOwner(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock.New error: %v", err)
	}
	defer db.Close()

	const me int64 = 42
	rows := newTaskRows().AddRow(1, me, "mine", nil, "todo", nil, nil, nil, nil, time.Now(), time.Now())
	// user_id = $1 に me が渡ることを WithArgs で保証する。
	mock.ExpectQuery("SELECT .* FROM tasks WHERE user_id = \\$1").
		WithArgs(me).
		WillReturnRows(rows)

	h := &TaskHandler{DB: db}
	req := withUser(httptest.NewRequest(http.MethodGet, "/tasks", nil), me)
	rec := httptest.NewRecorder()

	h.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body=%s", rec.Code, rec.Body.String())
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations (user_id not scoped?): %v", err)
	}
}

// List: context に userID が無い（未認証）なら 401。
func TestTaskList_Unauthenticated(t *testing.T) {
	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock.New error: %v", err)
	}
	defer db.Close()

	h := &TaskHandler{DB: db}
	req := httptest.NewRequest(http.MethodGet, "/tasks", nil) // userID を載せない
	rec := httptest.NewRecorder()

	h.List(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

// Create はリクエストボディの user_id を無視し、トークン由来の userID で作成する。
func TestTaskCreate_UsesTokenUserID(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock.New error: %v", err)
	}
	defer db.Close()

	const me int64 = 42
	const attacker int64 = 999 // ボディに混入させる他人のID

	// INSERT の第1引数（user_id）が me であることを保証。attacker であってはならない。
	rows := newTaskRows().AddRow(10, me, "t", nil, "todo", nil, nil, nil, nil, time.Now(), time.Now())
	mock.ExpectQuery("INSERT INTO tasks").
		WithArgs(me, "t", nil, nil, nil).
		WillReturnRows(rows)

	h := &TaskHandler{DB: db}
	// 悪意あるクライアントがボディに user_id を混ぜても無視されるべき。
	body := `{"user_id":999,"title":"t"}`
	req := withUser(httptest.NewRequest(http.MethodPost, "/tasks", strings.NewReader(body)), me)
	rec := httptest.NewRecorder()

	h.Create(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want 201; body=%s", rec.Code, rec.Body.String())
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations (used body user_id instead of token?): %v", err)
	}
}

// Delete: 自分のタスクは削除できる（rowsAffected=1 → 204）。
func TestTaskDelete_OwnTask(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock.New error: %v", err)
	}
	defer db.Close()

	const me int64 = 42
	mock.ExpectExec("DELETE FROM tasks WHERE id = \\$1 AND user_id = \\$2").
		WithArgs("5", me).
		WillReturnResult(sqlmock.NewResult(0, 1)) // 1 行削除

	h := &TaskHandler{DB: db}
	req := withUser(httptest.NewRequest(http.MethodDelete, "/tasks/5", nil), me)
	req.SetPathValue("id", "5")
	rec := httptest.NewRecorder()

	h.Delete(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want 204", rec.Code)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

// Delete: 他人のタスクは AND user_id で 0 行 → 404（存在を漏らさない）。
func TestTaskDelete_OtherUsersTask_NotFound(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock.New error: %v", err)
	}
	defer db.Close()

	const me int64 = 42
	mock.ExpectExec("DELETE FROM tasks WHERE id = \\$1 AND user_id = \\$2").
		WithArgs("5", me).
		WillReturnResult(sqlmock.NewResult(0, 0)) // 0 行（他人の行なので一致せず）

	h := &TaskHandler{DB: db}
	req := withUser(httptest.NewRequest(http.MethodDelete, "/tasks/5", nil), me)
	req.SetPathValue("id", "5")
	rec := httptest.NewRecorder()

	h.Delete(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404 for other user's task", rec.Code)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}

// GetByID: 他人のタスクは AND user_id で ErrNoRows → 404。
func TestTaskGetByID_OtherUsersTask_NotFound(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock.New error: %v", err)
	}
	defer db.Close()

	const me int64 = 42
	mock.ExpectQuery("SELECT .* FROM tasks WHERE id = \\$1 AND user_id = \\$2").
		WithArgs("5", me).
		WillReturnError(sql.ErrNoRows) // 他人の行は user_id 不一致で 0 行 = ErrNoRows

	h := &TaskHandler{DB: db}
	req := withUser(httptest.NewRequest(http.MethodGet, "/tasks/5", nil), me)
	req.SetPathValue("id", "5")
	rec := httptest.NewRecorder()

	h.GetByID(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404 for other user's task", rec.Code)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("unmet expectations: %v", err)
	}
}
