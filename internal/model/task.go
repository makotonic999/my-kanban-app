package model

import "time"

type Task struct {
	ID               int64      `json:"id"`
	UserID           int64      `json:"user_id"`
	Title            string     `json:"title"`
	Description      *string    `json:"description"`
	Status           string     `json:"status"`
	DueDate          *time.Time `json:"due_date"`
	EstimatedMinutes *int       `json:"estimated_minutes"`
	ActualMinutes    *int       `json:"actual_minutes"`
	CompletedAt      *time.Time `json:"completed_at"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}
