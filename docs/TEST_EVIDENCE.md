# テストエビデンス — フェーズ3（JWT認証 / テスト / OpenAPI）

> 記録日時: 2026-09-24
> 環境: `go version go1.27.0 windows/amd64`
> モジュール: `github.com/makotonic999/my-kanban-app`

このドキュメントは、フェーズ3（#5 JWT認証 / #6 テスト / #7 OpenAPI）の
検証を、実際に実行したコマンドの生ログとともに記録するものです。

---

## 1. サマリ

| 検証項目 | コマンド | 結果 |
|---|---|---|
| ビルド | `go build ./...` | ✅ exit=0 |
| 静的解析 | `go vet ./...` | ✅ exit=0 |
| テスト | `go test ./... -count=1 -v` | ✅ 全16テストPASS |
| 統合テスト | `docker compose up -d --build` → `./test-auth.ps1` | ✅ 全6チェックPASS（EXITCODE=0, 2026-09-24） |
| OpenAPI検証 | 一時Goバリデータ（`gopkg.in/yaml.v3`） | ✅ `YAML_OK openapi=3.0.3 paths=11 schemas=9` |

- テスト総数: **23件（すべてPASS）**
  - `internal/auth`: 8件
  - `internal/handler`（Login 4 + 認可 6）: 10件
  - `internal/middleware`（RequireAuth 4 + UserIDFrom 1）: 5件

### カバレッジ（`go test ./... -count=1 -cover`）

```
	github.com/makotonic999/my-kanban-app/cmd/api		coverage: 0.0% of statements
ok  	github.com/makotonic999/my-kanban-app/internal/auth	0.830s	coverage: 92.3% of statements
	github.com/makotonic999/my-kanban-app/internal/db		coverage: 0.0% of statements
ok  	github.com/makotonic999/my-kanban-app/internal/handler	1.570s	coverage: 7.5% of statements
?   	github.com/makotonic999/my-kanban-app/internal/metrics	[no test files]
ok  	github.com/makotonic999/my-kanban-app/internal/middleware	1.285s	coverage: 15.8% of statements
	github.com/makotonic999/my-kanban-app/internal/model		coverage: 0.0% of statements
	github.com/makotonic999/my-kanban-app/internal/telemetry		coverage: 0.0% of statements
```

> 補足: `auth` パッケージ（認証の中核ロジック）は **92.3%** をカバー。
> `handler` は Login のみを対象とするため全体比率としては低い（既存のtask/tagハンドラは
> DB統合が前提のため本フェーズではユニット対象外。統合テスト `test-auth.ps1` で補完）。

---

## 2. ビルド / 静的解析 ログ

```
### go version
go version go1.27.0 windows/amd64
### go build ./...
exit=0
### go vet ./...
exit=0
```

---

## 3. テスト実行ログ（`go test ./... -count=1 -v`）

```
?   	github.com/makotonic999/my-kanban-app/cmd/api	[no test files]
=== RUN   TestGenerateAndValidate_RoundTrip
--- PASS: TestGenerateAndValidate_RoundTrip (0.00s)
=== RUN   TestGenerateToken_EmptySecret
--- PASS: TestGenerateToken_EmptySecret (0.00s)
=== RUN   TestValidateToken_EmptySecret
--- PASS: TestValidateToken_EmptySecret (0.00s)
=== RUN   TestValidateToken_Expired
--- PASS: TestValidateToken_Expired (0.00s)
=== RUN   TestValidateToken_WrongSecret
--- PASS: TestValidateToken_WrongSecret (0.00s)
=== RUN   TestValidateToken_Tampered
--- PASS: TestValidateToken_Tampered (0.00s)
=== RUN   TestValidateToken_AlgNone
--- PASS: TestValidateToken_AlgNone (0.00s)
=== RUN   TestValidateToken_Garbage
--- PASS: TestValidateToken_Garbage (0.00s)
PASS
ok  	github.com/makotonic999/my-kanban-app/internal/auth	0.472s
?   	github.com/makotonic999/my-kanban-app/internal/db	[no test files]
=== RUN   TestLogin_Success
--- PASS: TestLogin_Success (0.11s)
=== RUN   TestLogin_WrongPassword
--- PASS: TestLogin_WrongPassword (0.11s)
=== RUN   TestLogin_UnknownUser
--- PASS: TestLogin_UnknownUser (0.00s)
=== RUN   TestLogin_BadJSON
--- PASS: TestLogin_BadJSON (0.00s)
PASS
ok  	github.com/makotonic999/my-kanban-app/internal/handler	0.855s
?   	github.com/makotonic999/my-kanban-app/internal/metrics	[no test files]
=== RUN   TestRequireAuth_NoHeader
--- PASS: TestRequireAuth_NoHeader (0.00s)
=== RUN   TestRequireAuth_MalformedHeader
--- PASS: TestRequireAuth_MalformedHeader (0.00s)
=== RUN   TestRequireAuth_InvalidToken
--- PASS: TestRequireAuth_InvalidToken (0.00s)
=== RUN   TestRequireAuth_ValidToken
--- PASS: TestRequireAuth_ValidToken (0.00s)
PASS
ok  	github.com/makotonic999/my-kanban-app/internal/middleware	0.737s
?   	github.com/makotonic999/my-kanban-app/internal/model	[no test files]
?   	github.com/makotonic999/my-kanban-app/internal/telemetry	[no test files]
```

---

## 4. 各テストが何を保証するか

### `internal/auth/jwt_test.go`（8件）
| テスト | 保証内容 |
|---|---|
| `TestGenerateAndValidate_RoundTrip` | 発行→検証で元の userID が復元できる |
| `TestGenerateToken_EmptySecret` | `JWT_SECRET` 未設定なら発行が `ErrEmptySecret` |
| `TestValidateToken_EmptySecret` | `JWT_SECRET` 未設定なら検証が `ErrEmptySecret` |
| `TestValidateToken_Expired` | 失効済みトークンを拒否 |
| `TestValidateToken_WrongSecret` | 別鍵で署名されたトークンを拒否 |
| `TestValidateToken_Tampered` | 改ざんされたトークンを拒否 |
| `TestValidateToken_AlgNone` | **alg=none 差し替え攻撃を拒否**（alg混同対策） |
| `TestValidateToken_Garbage` | 不正な文字列を拒否 |

### `internal/handler/auth_test.go`（4件、`go-sqlmock` 使用）
| テスト | 保証内容 |
|---|---|
| `TestLogin_Success` | 正しい資格情報で 200 とトークンを返す |
| `TestLogin_WrongPassword` | パスワード不一致で 401 |
| `TestLogin_UnknownUser` | ユーザー不在でも 401（**ユーザー列挙対策**：存在有無を漏らさない） |
| `TestLogin_BadJSON` | 不正JSONで 400 |

### `internal/middleware/auth_test.go`（4件、`httptest` 使用）
| テスト | 保証内容 |
|---|---|
| `TestRequireAuth_NoHeader` | Authorizationヘッダ無しで 401 |
| `TestRequireAuth_MalformedHeader` | `Bearer ` 前置きでないヘッダで 401 |
| `TestRequireAuth_InvalidToken` | 不正トークンで 401 |
| `TestRequireAuth_ValidToken` | 正常トークンで 200、かつ userID が context に伝播 |

---

## 5. 統合テスト（`test-auth.ps1`）

- 実サーバー（docker compose）に対する end-to-end 検証スクリプト。
- カバーするフロー: 登録 → ログイン → トークン付きで 200 → トークン無しで 401 →
  不正トークンで 401 → 誤パスワードで 401。
- **2026-09-24 に live 実行し全チェックPASS（EXITCODE=0）**。ログは下記セクション6を参照。

### 6. 統合テスト実行ログ（2026-09-24 実施 ✅）

環境: Docker `29.8.0`。`docker compose up -d --build` で全5コンテナ起動
（db=healthy, api=:8080, jaeger, prometheus, grafana）。live API に対して実行。

実行コマンド:
```powershell
docker compose up -d --build
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-auth.ps1
```

出力（`EXITCODE=0`、全6チェック OK）:
```
=== JWT Auth Integration Test ===

1. Creating user (auth-721567441639258374831946443@example.com)...
   User ID: 13

2. Logging in to obtain token...
   OK: token received (len=140)

3. Accessing protected GET /tasks WITH token (expect 200)...
   OK: 200 with valid token

4. Accessing protected GET /tasks WITHOUT token (expect 401)...
   OK: 401 without token

5. Accessing protected GET /tasks WITH invalid token (expect 401)...
   OK: 401 with invalid token

6. Logging in with wrong password (expect 401)...
   OK: 401 on wrong password

=== All auth checks passed ===
EXITCODE=0
```

再現性確認のため連続2回実行し、いずれも `EXITCODE=0`（全チェックPASS）。

#### 実行時に判明した問題と対処（デバッグ記録）
- **問題A**: `Invoke-WebRequest` を `-UseBasicParsing` なしで実行すると、ヘッドレス環境で
  レスポンス本文を安定取得できず、`.id` / `.token` が空になった。
  → 全リクエストに `-UseBasicParsing` を付与。
- **問題B（根本原因）**: `test-auth.ps1` が **UTF-8 (BOMなし)** で日本語コメントを含んでいたため、
  Windows PowerShell 5.x がANSIとして誤読し、後続の式評価（ユニークsuffix生成）が
  間欠的に空文字になっていた（→ 空suffixで重複メール衝突）。
  → スクリプトを **ASCIIのみ**に書き換え、空suffixガードを追加して恒久修正。


---

## 再現方法

```powershell
cd C:\Users\HP\my-kanban-app
go build ./...
go vet ./...
go test ./... -count=1 -v
go test ./... -count=1 -cover
```


---

## 7. 認可（Authorization）テスト（2026-09-24 追加）

「認証済みでも他人のリソースは触れない」ことを、ユニットと統合の両方で証明した。

### ユニット（`internal/handler/task_test.go`, `go-sqlmock`）
| テスト | 保証内容 |
|---|---|
| `TestTaskList_ScopedToOwner` | 一覧SQLに `WHERE user_id = $1` が付き、トークンの userID が渡る |
| `TestTaskList_Unauthenticated` | context に userID が無ければ 401 |
| `TestTaskCreate_UsesTokenUserID` | ボディに `user_id:999` を混入しても、INSERT はトークンの userID を使う |
| `TestTaskDelete_OwnTask` | 自分のタスク削除は 204 |
| `TestTaskDelete_OtherUsersTask_NotFound` | 他人のタスクは `AND user_id` で 0 行 → 404 |
| `TestTaskGetByID_OtherUsersTask_NotFound` | 他人のタスク取得は 0 行(ErrNoRows) → 404 |

`internal/middleware/auth_test.go` に `TestUserIDFrom`（context ヘルパ）を追加。

### カバレッジ（更新後）
```
ok  internal/auth        coverage: 92.3% of statements
ok  internal/handler     coverage: 25.2% of statements   (認可テスト追加で 7.5% → 25.2%)
ok  internal/middleware  coverage: 17.9% of statements
```

### 統合テスト（`test-auth.ps1`、全12チェック・EXITCODE=0）

認証6チェックに加え、**クロスユーザー分離**を実環境で確認:
```
7.  User A creates a task ....................... Task ID (owned by A)
8.  Create User B and log in .................... token received
9.  User B GET A's task ......................... OK: 404 (B cannot read A's task)
10. User B DELETE A's task ...................... OK: 404 (B cannot delete A's task)
11. User B list does not contain A's task ...... OK: A's task not visible to B (B has 0)
12. User A reads then deletes own task ......... OK: 200 then 204
=== All auth checks passed ===  EXITCODE=0
```

> これにより「複数ユーザーが同一APIを使っても、各自のデータは相互に隔離される」ことが、
> 単体（SQLの絞り込み）と実環境（本物のDB越しの分離）の両面から証明された。
