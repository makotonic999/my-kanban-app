CREATE TABLE users (
    id              BIGSERIAL     PRIMARY KEY,
    email           VARCHAR(255)  NOT NULL UNIQUE,
    password_digest VARCHAR(255)  NOT NULL,
    display_name    VARCHAR(100),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

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

CREATE TABLE tags (
    id         BIGSERIAL    PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users(id),
    name       VARCHAR(50)  NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, name)
);

CREATE INDEX idx_tags_user_id ON tags (user_id);

CREATE TABLE task_tags (
    task_id BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    tag_id  BIGINT NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
    PRIMARY KEY (task_id, tag_id)
);

CREATE INDEX idx_task_tags_tag_id ON task_tags (tag_id);

-- タスクの状態遷移を時系列で記録する履歴テーブル。
-- タスク作成時（to='todo', from=NULL）、status 変更時、完了時に 1 行ずつ追加する。
-- フェーズ6（AI 年間振り返り）の素材: リードタイム/サイクルタイム/差し戻し回数などを後で集計する。
CREATE TABLE task_status_events (
    id          BIGSERIAL     PRIMARY KEY,
    task_id     BIGINT        NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    from_status VARCHAR(50),                       -- 遷移前の状態（初回作成時は NULL）
    to_status   VARCHAR(50)   NOT NULL,            -- 遷移後の状態
    changed_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tse_task_id    ON task_status_events (task_id);
CREATE INDEX idx_tse_changed_at ON task_status_events (changed_at);

