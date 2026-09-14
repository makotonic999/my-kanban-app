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
