# 学習ノート: JWT認証フローの図解（2026-09-24）

> 対象: フェーズ3で実装した JWT 認証（`internal/auth`, `internal/handler/auth.go`, `internal/middleware/auth.go`）
> ねらい: 「login → token → 保護APIアクセス」の流れを、どこで何が起きるかを目で追えるようにする。

---

## 前提: これは何を実現しているか

KanbanApp を **複数ユーザーがアカウントを作って利用する**ための土台。
- **認証 (Authentication)**: 「あなたは誰か」を確かめる ← 今回実装済み
- **認可 (Authorization)**: 「あなたはこの操作をしてよいか」を制御 ← 今回は**未実装**（次のステップ）

現状は「正しいトークンを持つログイン済みユーザーだけが API を叩ける」ところまで。
「ユーザー42はユーザー42のタスクだけ」という所有権チェック（認可）はまだ無い。

---

## 1. 認証フロー全体（シーケンス）

ログイン → トークン取得 → 保護APIアクセス。

```
┌────────┐          ┌──────────────────────────────────────┐          ┌────────┐
│ Client │          │              API (:8080)              │          │   DB   │
│(あなた)│          │  Metrics → RequireAuth → Handler      │          │postgres│
└───┬────┘          └───────────────────┬──────────────────┘          └───┬────┘
    │ ① POST /login {email, password}    │                                 │
    │───────────────────────────────────>│ ② SELECT id, password_digest    │
    │                                    │    FROM users WHERE email=$1     │
    │                                    │────────────────────────────────>│
    │                                    │<─────────────── id, digest ──────│
    │                                    │ ③ bcrypt.CompareHashAndPassword  │
    │                                    │ ④ GenerateToken(id) を署名        │
    │<──────── {"token":"eyJ..."} ───────│                                 │
    │  ~ クライアントが token を保持 ~    │                                 │
    │ ⑤ GET /tasks                       │                                 │
    │    Authorization: Bearer eyJ...    │                                 │
    │───────────────────────────────────>│ ⑥ RequireAuth: ValidateToken     │
    │                                    │    署名OK? 期限内? → userID取得  │
    │                                    │    context に userID を格納      │
    │                                    │ ⑦ TaskHandler.List → SELECT tasks│
    │                                    │────────────────────────────────>│
    │<──────────── [tasks...] 200 ───────│<──────────────── rows ───────────│
```

- ②③④はログイン時（1回だけ・重い: DB照合 + bcrypt）
- ⑥はリクエストのたびに毎回（軽い: 署名計算だけ、DB不要）
- この非対称性が JWT（ステートレス認証）の利点。将来 ECS で複数台にしてもスケールする。

## 2. ミドルウェアの層（玉ねぎ構造）

```
       GET /tasks (Bearer eyJ...)
              ▼
  ┌───────────────────────────────────────────────┐
  │ MetricsMiddleware   ⏱ 計測開始                 │
  │  ┌─────────────────────────────────────────┐  │
  │  │ RequireAuth   🚪 門番                     │  │
  │  │   ・"Bearer " で始まる? ─No→ 401          │  │
  │  │   ・ValidateToken OK?   ─No→ 401          │  │
  │  │   ・OK → context に userID を積む          │  │
  │  │  ┌───────────────────────────────────┐   │  │
  │  │  │ TaskHandler.List  🍳 本体          │   │  │
  │  │  └───────────────────────────────────┘   │  │
  │  └─────────────────────────────────────────┘  │
  │                     ⏱ 計測終了・記録            │
  └───────────────────────────────────────────────┘
              ▼  200 OK [tasks...]
```

- `/login`, `POST /users`, `/metrics` は門番(RequireAuth)の層が無い（素通し）。
  - ログインするのにログインが必要、という矛盾を避けるため。

## 3. JWT の物理構造（ドット区切りの3パート）

```
  eyJhbGci...  .  eyJzdWIiOjEz...  .  dBjJ4kZ9x...
  └─ HEADER ─┘    └─ PAYLOAD ────┘    └ SIGNATURE ┘
  Base64URL(JSON)  Base64URL(JSON)   HMAC-SHA256の結果

  HEADER  = {"alg":"HS256","typ":"JWT"}
  PAYLOAD = {"sub":13, "exp":<明日>, "iat":<今>}     ← Base64なだけ。誰でも読める
  SIGNATURE = HMAC_SHA256(HEADER.PAYLOAD, JWT_SECRET) ← 秘密鍵を知る者しか作れない
```

- JWT が守るのは **機密性(読めなくする)ではなく完全性(改ざん検知)**。
- だから PAYLOAD に秘密情報を入れてはいけない。入れるのは user_id と exp のみ。

改ざん検知の仕組み:
```
攻撃者が PAYLOAD {"sub":13} → {"sub":1}(管理者) に書換え
  → SIGNATURE を作り直すには JWT_SECRET が必要（知らない）
  → サーバーが署名を再計算 → 不一致 → 401 で拒否 ✅
```

## 4. ValidateToken の判定フロー（門番の頭の中）

```
   token 受領
  [1] JWT_SECRET 設定済み?   ─No→ ErrEmptySecret
  [2] alg は HMAC?           ─No→ ErrInvalidToken  ← alg=none攻撃を防ぐ
  [3] 署名は SECRET と一致?   ─No→ ErrInvalidToken  ← 改ざん/鍵違いを弾く
  [4] 有効期限(exp)は未来?    ─No→ ErrInvalidToken  ← 失効を弾く
  [5] sub(userID) 取り出せる? ─No→ ErrInvalidToken
   → userID を返す ✅
```

各関門に対応する単体テスト:
```
  [1] → TestValidateToken_EmptySecret
  [2] → TestValidateToken_AlgNone
  [3] → TestValidateToken_Tampered / _WrongSecret
  [4] → TestValidateToken_Expired
  正常 → TestGenerateAndValidate_RoundTrip
```

---

## 用語まとめ

| 用語 | 意味 | 今回のコード |
|---|---|---|
| 認証 (AuthN) | 誰か? | `Login` + `ValidateToken` |
| 認可 (AuthZ) | 何してよいか? | **未実装**（context の userID を使って将来追加） |
| ステートレス | サーバーが状態を持たない | JWT。サーバーは userID を覚えず署名で判断 |
| 完全性 | 改ざんされていないこと | HMAC署名で担保 |
| bcrypt | 意図的に遅いパスワードハッシュ | `CompareHashAndPassword` |

## 次のステップ
- 認可の実装（例: `TaskHandler` で context の userID と行の user_id を突き合わせ、他人のタスクを触れないようにする）
- そのための「所有権テスト」の追加
