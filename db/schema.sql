-- =============================================================================
-- 公開用スキーマ（冪等）— my-kanban-app
--
-- Neon などの新規 PostgreSQL に対して「1 回流せば全テーブルが揃う」ことを目的とする。
-- すべて IF NOT EXISTS / 条件付きで書いてあるため、既存 DB に対して再実行しても安全。
--
-- 使い方（例: Neon）:
--   psql "<Neon の接続文字列>" -f db/schema.sql
--   または Neon の SQL エディタにこの内容を貼り付けて実行。
--
-- 注意: 本プロジェクトはマイグレーション自動適用の仕組みを持たない。
--       スキーマ変更時はこのファイルと db/init.sql の両方を更新すること。
-- =============================================================================

CREATE TABLE IF NOT EXISTS users (
    id              BIGSERIAL     PRIMARY KEY,
    email           VARCHAR(255)  NOT NULL UNIQUE,
    password_digest VARCHAR(255)  NOT NULL,
    display_name    VARCHAR(100),
    rules           TEXT          NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
-- 既存 users に rules が無い場合に備えて（古い DB への再適用用）。
ALTER TABLE users ADD COLUMN IF NOT EXISTS rules TEXT NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS tasks (
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

CREATE INDEX IF NOT EXISTS idx_tasks_user_id      ON tasks (user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status       ON tasks (status);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date     ON tasks (due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_completed_at ON tasks (completed_at);

CREATE TABLE IF NOT EXISTS tags (
    id         BIGSERIAL    PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users(id),
    name       VARCHAR(50)  NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_tags_user_id ON tags (user_id);

CREATE TABLE IF NOT EXISTS task_tags (
    task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    tag_id  BIGINT NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
    PRIMARY KEY (task_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_task_tags_tag_id ON task_tags (tag_id);

-- タスクの状態遷移を時系列で記録する履歴テーブル。
CREATE TABLE IF NOT EXISTS task_status_events (
    id          BIGSERIAL     PRIMARY KEY,
    task_id     BIGINT        NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    from_status VARCHAR(50),
    to_status   VARCHAR(50)   NOT NULL,
    changed_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tse_task_id    ON task_status_events (task_id);
CREATE INDEX IF NOT EXISTS idx_tse_changed_at ON task_status_events (changed_at);
