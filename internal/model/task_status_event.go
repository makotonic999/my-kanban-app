package model

import "time"

// TaskStatusEvent はタスクの状態遷移 1 回分の記録。
// タスク作成時（FromStatus=nil, ToStatus="todo"）、status 変更時、完了時に 1 行追加される。
type TaskStatusEvent struct {
	ID         int64     `json:"id"`
	TaskID     int64     `json:"task_id"`
	FromStatus *string   `json:"from_status"` // 初回作成時は nil
	ToStatus   string    `json:"to_status"`
	ChangedAt  time.Time `json:"changed_at"`
}
