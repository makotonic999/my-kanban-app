package db

import (
	"database/sql"
	"log"
	"time"

	_ "github.com/lib/pq"
)

// New は DSN で PostgreSQL に接続する。
//
// 起動直後に DB がまだ応答しない場合（例: Neon などのスケールゼロ DB の
// コールドスタート、compose で db がまだ healthy 前）に備え、Ping を数回リトライする。
// すべて失敗した場合のみ致命的エラーで終了する。
func New(dsn string) *sql.DB {
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatal(err)
	}

	// 1s, 2s, 3s... と間隔を空けて最大 10 回（合計 ~55s）まで接続を試みる。
	const maxAttempts = 10
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		if err = db.Ping(); err == nil {
			return db
		}
		if attempt < maxAttempts {
			wait := time.Duration(attempt) * time.Second
			log.Printf("db ping failed (attempt %d/%d): %v; retrying in %s",
				attempt, maxAttempts, err, wait)
			time.Sleep(wait)
		}
	}

	log.Fatalf("db ping failed after %d attempts: %v", maxAttempts, err)
	return nil // 到達しない（log.Fatalf が exit する）
}
