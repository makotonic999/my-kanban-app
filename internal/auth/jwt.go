// Package auth はJWT（JSON Web Token）の発行と検証を担う。
//
// 方式: HS256（HMAC-SHA256、共通鍵1個）。有効期限は24時間。
// 秘密鍵は環境変数 JWT_SECRET から読み込む（コード/gitに実値を置かない）。
package auth

import (
	"errors"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// TokenTTL はアクセストークンの有効期限。
const TokenTTL = 24 * time.Hour

// ErrEmptySecret はJWT_SECRETが未設定のときに返る。
var ErrEmptySecret = errors.New("auth: JWT_SECRET is not set")

// ErrInvalidToken はトークンの署名・期限・クレームが不正なときに返る。
var ErrInvalidToken = errors.New("auth: invalid token")

// secret は署名鍵を返す。未設定なら空スライス（呼び出し側でGenerate/Validate時に検出）。
func secret() []byte { return []byte(os.Getenv("JWT_SECRET")) }

// GenerateToken は userID を主張(sub)に持つHS256署名JWTを発行する（有効期限 TokenTTL）。
func GenerateToken(userID int64) (string, error) {
	if len(secret()) == 0 {
		return "", ErrEmptySecret
	}
	now := time.Now()
	claims := jwt.MapClaims{
		"sub": userID,
		"exp": now.Add(TokenTTL).Unix(),
		"iat": now.Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(secret())
}

// ValidateToken は署名と期限を検証し、userID を返す。
//
// keyFunc で署名方式がHMACであることを必ず確認する。これは
// "alg混同攻撃"（alg=none や RS256 への差し替え）を防ぐため。
func ValidateToken(tokenString string) (int64, error) {
	if len(secret()) == 0 {
		return 0, ErrEmptySecret
	}
	token, err := jwt.Parse(tokenString, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return secret(), nil
	})
	if err != nil || !token.Valid {
		return 0, ErrInvalidToken
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return 0, ErrInvalidToken
	}

	// JSON数値はfloat64でデコードされる点に注意。
	sub, ok := claims["sub"].(float64)
	if !ok {
		return 0, ErrInvalidToken
	}
	return int64(sub), nil
}
