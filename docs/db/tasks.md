# テーブル定義書: `tasks`

## 概要

カンバンボードの各タスクを管理するコアテーブル。
ガントチャートでの工数管理と、1年後のAIによる活動振り返り分析の両方を支えるデータ構造とする。

---

## カラム定義

| カラム名 | データ型 | NULL | デフォルト | 説明 |
|---|---|---|---|---|
| `id` | `BIGSERIAL` | NOT NULL | 自動採番 | 主キー |
| `user_id` | `BIGINT` | NOT NULL | — | ユーザーID（FK → `users.id`） |
| `title` | `VARCHAR(255)` | NOT NULL | — | タスク名（ユーザー入力） |
| `description` | `TEXT` | NULL | — | 詳細メモ |
| `status` | `VARCHAR(50)` | NOT NULL | `'todo'` | ステータス（`todo` / `doing` / `done`） |
| `due_date` | `DATE` | NULL | — | 期日（ガントチャート表示・範囲検索用） |
| `estimated_minutes` | `INT` | NULL | — | 見積もり時間（分）。ガント工数 ＆ AI予測比較用 |
| `actual_minutes` | `INT` | NULL | — | 実績時間（分）。タイマー等で自動計測・保存。AI分析用 |
| `completed_at` | `TIMESTAMPTZ` | NULL | — | 完了日時。`status` が `done` になった瞬間にアプリ側で自動記録 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | `NOW()` | 作成日時 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | `NOW()` | 更新日時 |

---

## インデックス

| インデックス名 | カラム | 種別 | 目的 |
|---|---|---|---|
| `tasks_pkey` | `id` | PRIMARY KEY (B-Tree) | 主キー検索 |
| `idx_tasks_user_id` | `user_id` | B-Tree | ユーザー別タスク一覧取得 |
| `idx_tasks_status` | `status` | B-Tree | ステータス別フィルタリング |
| `idx_tasks_due_date` | `due_date` | B-Tree | 期日ソート・ガントチャート範囲検索 |
| `idx_tasks_completed_at` | `completed_at` | B-Tree | AI分析用の完了日時集計（月別・年別） |

---

## DDL

```sql
CREATE TABLE tasks (
    id                BIGSERIAL     PRIMARY KEY,
    user_id           BIGINT        NOT NULL REFERENCES users(id),
    title             VARCHAR(255)  NOT NULL,
    description       TEXT,
    status            VARCHAR(50)   NOT NULL DEFAULT 'todo',
    due_date          DATE,
    estimated_minutes INT,
    actual_minutes    INT,
    completed_at      TIMESTAMPTZ,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tasks_user_id      ON tasks (user_id);
CREATE INDEX idx_tasks_status       ON tasks (status);
CREATE INDEX idx_tasks_due_date     ON tasks (due_date);
CREATE INDEX idx_tasks_completed_at ON tasks (completed_at);
```

---

## 備考

- `completed_at` はアプリ層で `status = 'done'` への更新と同時にセットする。`NULL` = 未完了。
- `actual_minutes` はタイマー機能による自動計測値を保存する。手動入力も許容する。
- `estimated_minutes` と `actual_minutes` の差分はAIによる「見積もり精度の振り返り」に活用する。
- `status` は将来的に `ENUM` 型または `statuses` テーブルへの正規化を検討する。
- `updated_at` の自動更新はアプリケーション層またはトリガーで制御する。
- タグ機能（N:M リレーション）は `tags` テーブルおよび中間テーブル `task_tags` で別途管理する（→ `docs/db/tags.md`）。
