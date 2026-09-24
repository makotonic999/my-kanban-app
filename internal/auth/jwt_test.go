package auth

import (
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const testSecret = "test-secret-for-unit-tests-0123456789abcdef"

func TestGenerateAndValidate_RoundTrip(t *testing.T) {
	t.Setenv("JWT_SECRET", testSecret)

	const wantID int64 = 42
	tok, err := GenerateToken(wantID)
	if err != nil {
		t.Fatalf("GenerateToken returned error: %v", err)
	}
	if tok == "" {
		t.Fatal("GenerateToken returned empty token")
	}

	gotID, err := ValidateToken(tok)
	if err != nil {
		t.Fatalf("ValidateToken returned error: %v", err)
	}
	if gotID != wantID {
		t.Fatalf("userID mismatch: got %d, want %d", gotID, wantID)
	}
}

func TestGenerateToken_EmptySecret(t *testing.T) {
	t.Setenv("JWT_SECRET", "")
	if _, err := GenerateToken(1); err != ErrEmptySecret {
		t.Fatalf("expected ErrEmptySecret, got %v", err)
	}
}

func TestValidateToken_EmptySecret(t *testing.T) {
	t.Setenv("JWT_SECRET", "")
	if _, err := ValidateToken("anything"); err != ErrEmptySecret {
		t.Fatalf("expected ErrEmptySecret, got %v", err)
	}
}

func TestValidateToken_Expired(t *testing.T) {
	t.Setenv("JWT_SECRET", testSecret)

	claims := jwt.MapClaims{
		"sub": int64(7),
		"exp": time.Now().Add(-1 * time.Hour).Unix(), // 1時間前に失効
		"iat": time.Now().Add(-2 * time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(testSecret))
	if err != nil {
		t.Fatalf("failed to sign expired token: %v", err)
	}

	if _, err := ValidateToken(signed); err != ErrInvalidToken {
		t.Fatalf("expected ErrInvalidToken for expired token, got %v", err)
	}
}

func TestValidateToken_WrongSecret(t *testing.T) {
	t.Setenv("JWT_SECRET", testSecret)
	tok, err := GenerateToken(99)
	if err != nil {
		t.Fatalf("GenerateToken error: %v", err)
	}

	// 検証時に別の鍵に差し替える → 署名不一致で失敗するべき。
	t.Setenv("JWT_SECRET", "a-completely-different-secret-value")
	if _, err := ValidateToken(tok); err != ErrInvalidToken {
		t.Fatalf("expected ErrInvalidToken for wrong secret, got %v", err)
	}
}

func TestValidateToken_Tampered(t *testing.T) {
	t.Setenv("JWT_SECRET", testSecret)
	tok, err := GenerateToken(5)
	if err != nil {
		t.Fatalf("GenerateToken error: %v", err)
	}

	// ペイロード(2番目のセグメント)の1文字を書き換えて署名不一致を必ず起こす。
	// 署名末尾の書き換えは base64url の末尾ビットの都合で同一デコードになる場合があり不安定なため避ける。
	parts := strings.Split(tok, ".")
	if len(parts) != 3 {
		t.Fatalf("unexpected token format: %q", tok)
	}
	payload := []byte(parts[1])
	// 先頭文字を別の文字に確実に変える。
	if payload[0] == 'A' {
		payload[0] = 'B'
	} else {
		payload[0] = 'A'
	}
	tampered := parts[0] + "." + string(payload) + "." + parts[2]

	if _, err := ValidateToken(tampered); err != ErrInvalidToken {
		t.Fatalf("expected ErrInvalidToken for tampered token, got %v", err)
	}
}

// TestValidateToken_AlgNone は alg=none への差し替え攻撃を拒否することを確認する。
func TestValidateToken_AlgNone(t *testing.T) {
	t.Setenv("JWT_SECRET", testSecret)

	claims := jwt.MapClaims{
		"sub": int64(1),
		"exp": time.Now().Add(time.Hour).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodNone, claims)
	signed, err := token.SignedString(jwt.UnsafeAllowNoneSignatureType)
	if err != nil {
		t.Fatalf("failed to create none-signed token: %v", err)
	}

	if _, err := ValidateToken(signed); err != ErrInvalidToken {
		t.Fatalf("expected ErrInvalidToken for alg=none token, got %v", err)
	}
}

func TestValidateToken_Garbage(t *testing.T) {
	t.Setenv("JWT_SECRET", testSecret)
	if _, err := ValidateToken("not.a.jwt"); err != ErrInvalidToken {
		t.Fatalf("expected ErrInvalidToken for garbage input, got %v", err)
	}
}
