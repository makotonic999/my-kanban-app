# テーブル定義書: `users`

## 概要

アプリケーションの利用者を管理するテーブル。
`tasks` および `tags` の親エンティティであり、全データはユーザー単位で分離される。

---

## カラム定義

| カラム名 | データ型 | NULL | デフォルト | 説明 |
|---|---|---|---|---|
| `id` | `BIGSERIAL` | NOT NULL | 自動採番 | 主キー |
| `email` | `VARCHAR(255)` | NOT NULL | — | メールアドレス（ログインID） |
| `password_digest` | `VARCHAR(255)` | NOT NULL | — | ハッシュ化済みパスワード（bcrypt） |
| `display_name` | `VARCHAR(100)` | NULL | — | 表示名 |
| `created_at` | `TIMESTAMPTZ` | NOT NULL | `NOW()` | 作成日時 |
| `updated_at` | `TIMESTAMPTZ` | NOT NULL | `NOW()` | 更新日時 |

---

## インデックス

| インデックス名 | カラム | 種別 | 目的 |
|---|---|---|---|
| `users_pkey` | `id` | PRIMARY KEY (B-Tree) | 主キー検索 |
| `uq_users_email` | `email` | UNIQUE (B-Tree) | メールアドレスの重複防止・ログイン検索 |

---

## DDL

```sql
CREATE TABLE users (
    id              BIGSERIAL     PRIMARY KEY,
    email           VARCHAR(255)  NOT NULL UNIQUE,
    password_digest VARCHAR(255)  NOT NULL,
    display_name    VARCHAR(100),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
```

---

## 備考

- `password_digest` には平文パスワードを絶対に保存しない。Go側で `bcrypt` によりハッシュ化してから保存する。
- `email` の UNIQUE 制約がログイン時の検索インデックスを兼ねる。
- フェーズ5（モバイルアプリ化）で OAuth / JWT 認証を導入する際は、`provider` / `provider_id` カラムの追加を検討する。
- 現フェーズは個人利用を想定しているため、ユーザー数は少数。スケールを意識した設計変更はフェーズ3以降で対応する。
