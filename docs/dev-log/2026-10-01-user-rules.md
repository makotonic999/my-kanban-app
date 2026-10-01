# dev-log: 2026-10-01 — カンバン上部に「ルール」ゾーン（独自性）

## この日やったこと
UI 見直しの一環で独自性を出すため、カンバン上部（タスク追加フォームの上）に
ユーザーごとの**運用ルール**を書き置ける「ルール」ゾーンを追加した。
通常は表示、「編集」ボタンでテキストエリアになり「保存」で DB に永続化する。

あわせて、朝のレビューで気づいた文言の不統一も先に別 PR(#16) で修正済み:
- ログイン/ログアウト/アカウント作成 → **サインイン/サインアウト/サインアップ**に統一。
- ヘッダーのロゴ飾り(▚)と `/ board` を削除し **KANBAN** のみに。

## 仕様（合意済み）
- 表示 ⇄ 編集の切り替え（編集 → テキストエリア → 保存）。
- 保存先は **DB**（localStorage ではなく本格対応）。ユーザーごとに 1 つ。
- 入力は**自由テキスト**（複数行）。
- 見出しは「ルール」。**未設定のうちは例ルールを薄い字（プレースホルダ）**で表示:
  1. In Progress は4つ以上キープしない。
  2. タスク名は一目でわかるように。
  3. Done はこまめに。完了は小さく刻む。（アシスタント案）

## 実装（フルスタック）
### DB
- `users` に `rules TEXT NOT NULL DEFAULT ''` を追加。
  - 新規 DB: `db/init.sql` を更新。
  - 稼働中 DB: `ALTER TABLE users ADD COLUMN IF NOT EXISTS rules TEXT NOT NULL DEFAULT ''`（冪等）で適用済み。
- 1 ユーザー 1 ルールの性質上、新テーブルではなく users への列追加が素直と判断。

### API（`internal/handler/user.go` + `cmd/api/main.go`）
- `GET /me/rules` → `{"rules": "..."}`（自分のルール取得）。
- `PUT /me/rules`（body `{"rules":"..."}`）→ 上書き保存して返す。
- どちらも**認証必須**（`protect` でラップ）。userID は**トークン由来**（context から取得）。

### フロント（`frontend/src/`）
- `api.ts`: `getRules()` / `updateRules(rules)` を追加。
- `components/Rules.tsx`（新規）: 表示/編集/保存の状態管理。未設定時は例ルールをプレースホルダ表示。
  保存済みは `whitespace-pre-wrap` で改行そのまま表示。ダークテーマ（`.glass`）に馴染む見た目。
- `components/Board.tsx`: 作成フォームの直前に `<Rules />` を配置。401 は `onUnauthorized` へ。

## 検証エビデンス
- `go build` / `go vet` / `gofmt` OK。`go test ./...` 全 OK。
- `tsc --noEmit && vite build` = exit 0。
- 実 API（api 再ビルド後）:
  - 初期ルールは空（`{"rules":""}`）。
  - `PUT /me/rules` で保存 → DB の `users.rules` に改行付きで正しく保存されることを確認。
  - 未認証 `GET /me/rules` は **401**。
- 検証用テストユーザーは削除済み（DB クリーン）。

## 設計メモ
- マイグレーションは従来どおり「init.sql 更新 + 稼働 DB へ手動 SQL」の両建て（自動化は将来課題）。
- 既存データは壊さない後方互換の列追加（DEFAULT '' なので既存ユーザーは空ルールになる）。
- 将来 AWS 本番 RDS に載せる際は、この ALTER も移行手順に含める必要がある。
