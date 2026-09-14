# ER図

## テーブル関連図

```mermaid
erDiagram
    users {
        BIGSERIAL   id              PK
        VARCHAR255  email           UK
        VARCHAR255  password_digest
        VARCHAR100  display_name
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    tasks {
        BIGSERIAL   id                PK
        BIGINT      user_id           FK
        VARCHAR255  title
        TEXT        description
        VARCHAR50   status
        DATE        due_date
        INT         estimated_minutes
        INT         actual_minutes
        TIMESTAMPTZ completed_at
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    tags {
        BIGSERIAL   id         PK
        BIGINT      user_id    FK
        VARCHAR50   name
        TIMESTAMPTZ created_at
    }

    task_tags {
        BIGINT task_id FK
        BIGINT tag_id  FK
    }

    users ||--o{ tasks     : "1:N"
    users ||--o{ tags      : "1:N"
    tasks ||--o{ task_tags : "1:N"
    tags  ||--o{ task_tags : "1:N"
```

---

## リレーション説明

| リレーション | 種別 | 説明 |
|---|---|---|
| `users` → `tasks` | 1:N | 1ユーザーは複数タスクを持つ |
| `users` → `tags` | 1:N | 1ユーザーは複数タグを持つ |
| `tasks` ↔ `tags` | N:M | 中間テーブル `task_tags` で結合 |

---

## 参照先テーブル定義書

- [`docs/db/users.md`](./users.md)
- [`docs/db/tasks.md`](./tasks.md)
- [`docs/db/tags.md`](./tags.md)
