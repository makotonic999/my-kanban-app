# テーブル定義書: `tags` / `task_tags`

## 概要

タスクへのタグ付けを管理するテーブル群。
`tasks` と `tags` は多対多（N:M）のリレーションであり、中間テーブル `task_tags` で結合する。

```
tasks 1 ──── N task_tags N ──── 1 tags
```

---

## カラム定義

### `tags`

| カラム名 | データ型 | NULL | デフォルト | 説明 |
|---|---|---|---|---|
| `id` | `BIGSERIAL` | NOT NULL | 自動採番 | 主キー |
| `user_id` | `BIGINT` | NOT NULL | — | タグ所有ユーザー（FK → `users.id`） |
| `name` | `VARCHAR(50)` | NOT NULL | — | タグ名（例: `仕事`, `学習`, `個人`） |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | `NOW()` | 作成日時 |

### `task_tags`（中間テーブル）

| カラム名 | データ型 | NULL | デフォルト | 説明 |
|---|---|---|---|---|
| `task_id` | `BIGINT` | NOT NULL | — | FK → `tasks.id` |
| `tag_id` | `BIGINT` | NOT NULL | — | FK → `tags.id` |

---

## インデックス

| インデックス名 | テーブル | カラム | 種別 | 目的 |
|---|---|---|---|---|
| `tags_pkey` | `tags` | `id` | PRIMARY KEY (B-Tree) | 主キー検索 |
| `idx_tags_user_id` | `tags` | `user_id` | B-Tree | ユーザー別タグ一覧取得 |
| `uq_tags_user_id_name` | `tags` | `(user_id, name)` | UNIQUE (B-Tree) | 同一ユーザー内のタグ名重複防止 |
| `task_tags_pkey` | `task_tags` | `(task_id, tag_id)` | PRIMARY KEY (B-Tree) | 複合主キー・重複防止 |
| `idx_task_tags_tag_id` | `task_tags` | `tag_id` | B-Tree | タグ → タスクの逆引き（AI集計用） |

---

## DDL

```sql
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
```

---

## 備考

- `task_tags` の複合主キー `(task_id, tag_id)` が一意制約と主キーインデックスを兼ねる。
- `ON DELETE CASCADE` により、タスクまたはタグ削除時に `task_tags` のレコードも自動削除される。
- `idx_task_tags_tag_id` は「このタグが付いたタスク一覧」をAIが集計する際に使用する。
- タグはユーザーごとに管理する（`user_id` で分離）。異なるユーザー間でのタグ共有は現フェーズでは対象外。
