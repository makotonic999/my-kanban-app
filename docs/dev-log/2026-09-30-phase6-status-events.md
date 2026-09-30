# dev-log: 2026-09-30（フェーズ6 下ごしらえ）— 状態遷移イベントの自動記録

## この日やったこと
見積もり時間の手入力をやめた流れから、「タスクの状態遷移（いつ To Do / In Progress / Done に
入ったか）を**自動で**貯める」方向へ舵を切った。フェーズ6（AI 年間振り返り）の素材として、
手入力の主観データより自動で貯まる客観データ（リードタイム・サイクルタイム・差し戻し回数）の方が
筋が良いという判断。

案A（`tasks.started_at` 列を1本追加）と案B（履歴テーブル新設）を比較し、**案B を採用**。
「実行時のパフォーマンスは重くならず（1遷移=1行 INSERT）、得られるデータの価値が段違い」なため。
`feature/phase6-status-events` ブランチ（main 起点）で実装。

## 設計
### テーブル `task_status_events`
```sql
CREATE TABLE task_status_events (
    id          BIGSERIAL   PRIMARY KEY,
    task_id     BIGINT      NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    from_status VARCHAR(50),            -- 遷移前（初回作成時は NULL）
    to_status   VARCHAR(50) NOT NULL,   -- 遷移後
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_tse_task_id    ON task_status_events (task_id);
CREATE INDEX idx_tse_changed_at ON task_status_events (changed_at);
```

### 記録する遷移
1. **作成時**: `from=NULL → to='todo'`（起点を記録）
2. **Update で status 変更時**: `from=旧 → to=新`（status が実際に変わった時だけ）
3. **Complete**: `from=旧 → to='done'`（既に done なら記録しない）

### 原子性
各ハンドラで「tasks の作成/更新 + イベント INSERT」を**同一トランザクション**で実行。
Update / Complete は遷移前 status を `SELECT ... FOR UPDATE` で行ロックして取得してから更新し、
`from_status` を正確に記録する。

## 実装
- `db/init.sql`: `task_status_events` テーブル + インデックスを追記（新規 DB 用）。
- 既存の稼働中 DB へは `CREATE TABLE IF NOT EXISTS ...` で手動マイグレーション適用（冪等）。
  ※本プロジェクトはマイグレーション自動適用の仕組みが無く、スキーマは手動運用。
  新規 DB は init.sql、既存 DB は手動 SQL の**両建て**で反映する運用。
- `internal/model/task_status_event.go`（新規）: `TaskStatusEvent` 構造体（FromStatus は `*string`）。
- `internal/handler/task.go`:
  - `insertStatusEvent(ctx, tx, taskID, from, to)` ヘルパーを追加（tx 内で 1 行 INSERT）。
  - `Create` / `Update` / `Complete` をトランザクション化し、上記ルールでイベント記録。
  - `context` を import 追加。
- `internal/handler/task_test.go`: `TestTaskCreate_UsesTokenUserID` を tx 対応に更新
  （`ExpectBegin` → INSERT tasks → INSERT task_status_events → `ExpectCommit`）。

## 検証エビデンス
- `go build ./...` = OK、`go vet ./...` = OK、`go test ./...` = 全 **ok**（handler 含む）。
- `docker compose up -d --build api` で新コードを反映して実挙動を確認:
  - 作成→in_progress→done の一連で `task_status_events` に **3 行**（`NULL→todo` / `todo→in_progress`
    / `in_progress→done`）が正しい順序・タイムスタンプで記録された。
  - **誤記録防止**: タイトルのみ更新・同一 status への更新（todo→todo）では**イベントが増えない**
    （作成時の 1 行のみ）ことを確認。
  - **CASCADE**: テストタスク削除で関連イベントも自動削除（孤児 0 件）を確認。
- 検証で作成したテストuser/taskは削除済み（DBクリーン）。

## 設計上の割り切り / 注意
- 履歴テーブル導入前から存在するタスクには過去の遷移ログが無い（導入以降のみ蓄積）。
- `updated_at` は従来どおり「最終更新時刻」。遷移の真実は `task_status_events` を見る。
- 実行時パフォーマンスへの影響は無視できる（個人利用で 1 日数十遷移、各 1 行 INSERT）。
- 将来 AWS 本番 RDS へ適用する際は、この CREATE TABLE を移行手順に含める必要がある。

## 次のステップ（候補）
- 集計クエリの試作（リードタイム＝created→done、サイクルタイム＝最初の in_progress→done、
  差し戻し回数＝done 以外へ戻った回数 など）。
- イベント参照用の API（`GET /tasks/{id}/events` 等）— フロントやAIから履歴を読む口。
- フロント（別ブランチ `feature/phase5-frontend-dark-keyboard`）の PR 化・デモ素材づくり。
