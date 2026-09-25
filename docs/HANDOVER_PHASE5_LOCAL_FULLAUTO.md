# 引継ぎドキュメント - 2026-09-25（フェーズ5 一区切り / 次回: ローカルのフル自動化）

> この日は、前日ブレーカーで中断したフェーズ5作業を git 点検から復元し、フロント実装〜デプロイ経路
> 〜ローカル E2E まで完了。公開に向けた機密対応（AWS アカウントID マスク）とポートフォリオ掲載も済ませた。
> **次回は「Docker Compose とは何か」を理解するところから再開し、ローカル環境のフル自動化を実装する。**

---

## 現在地

- フェーズ1〜4: 完了 ✅
- **フェーズ5（Web フロント）**: UI 実装 / JWT フロー / CORS / ホスティング plan 通過 / デプロイ経路 / ローカル E2E まで完了 ✅
  - 残: 実 `terraform apply`（課金のため保留）、独自ドメイン+ACM、タグ UI・期日/見積もり入力
- フェーズ6（AI）/ 7（モバイル）: 未着手

マージ済み PR: #5（フロント+CORS）/ #6（hosting plan）/ #7（deploy path + E2E）/ #8（account id マスク + 振り返り）。
main は公開に耐える状態（実アカウントID は `git grep` で 0 件を確認済み）。

---

## 次回やること（決定済みの方針）

### ゴール: ローカル環境のフル自動化（環境1）
「PC 起動 → Docker Desktop 自動起動 → KanbanApp 一式が自動で立ち上がる」状態にする。
**これはローカル（自分用）だけの話。AWS 版・モバイル版とは別物**（下記「3 環境の分離」参照）。

### 再開の入り口: 「Docker Compose とは何か」の理解から
ユーザーは compose の概念をこの日に学び始めた段階。次回はまず概念の再確認から入る。
- コンテナ = アプリを実行環境ごと箱詰めしたもの
- Docker = 箱を作る/動かす道具
- Compose = 複数の箱の構成を 1 ファイル（`docker-compose.yml`）に書いてまとめて起動する道具
- `docker compose up` で全サービスが正しい順序・連携で起動、`down` で停止
- アナロジー: compose = レストランの「開店手順書」、`up` = 「開店!」で全ステーション一斉起動

### 実装の合意事項（前回セッションで決定）
1. **compose を用途で分割する**
   - `docker-compose.yml` = コア（`db` + `api` + `frontend`）。日々使い用・軽量。
   - `docker-compose.observability.yml` = `jaeger` / `prometheus` / `grafana`。見たい時だけ `-f` で追加。
   - 注意: `docker compose up` のデフォルト挙動（既存の dev/CI 運用）を壊さないこと。
2. **フロントをコンテナ化（dev server 方式）**
   - 今は `frontend/` で手動 `npm run dev`。これを compose の `frontend` サービスに載せる。
   - dev server 方式（ホットリロード維持）。nginx 静的配信ではなく `npm run dev` をコンテナで。
   - フロント用 Dockerfile を新規作成（例: `frontend/Dockerfile.dev`）。
3. **`restart: unless-stopped`** を各サービスに付与 → Docker Desktop 起動で自動復帰。
4. **Docker Desktop の自動起動設定**（Settings → General → Start Docker Desktop when you sign in）はユーザー操作で。
5. **3 環境分離の設計をドキュメント化**（README or docs）。ポートフォリオ的に「なぜ 3 環境に分けたか」を明記。

### 3 環境の分離（設計の全体像）
| 環境 | 目的 | フロント | バックエンド | DB | 分け方 |
|---|---|---|---|---|---|
| 1. ローカル | 日々使う・データ蓄積 | compose 内 Vite | compose の Go API | compose の Postgres（永続ボリューム） | `docker-compose.yml`（設定） |
| 2. AWS 版 | Web 公開 | S3+CloudFront | ECS Fargate | RDS | `terraform/`（設定） |
| 3. モバイル版 | 将来 Google Play | Flutter/RN 別アプリ | **AWS 版 API を共用** | AWS 版 RDS 共用 | **別リポジトリ**（フェーズ7 で新設） |

**重要な設計判断（次回ブレないように）**:
- 環境はブランチで分けない（アンチパターン）。**コードは 1 つ、設定で分ける**。
- ローカル/AWS は同じソース。違いは設定（`docker-compose` vs `terraform`）と環境変数
  （`VITE_API_BASE_URL` / `DATABASE_URL` / `CORS_ALLOWED_ORIGINS`）だけ。既にこの構造になっている。
- モバイルだけは言語もツールチェーンもリリースサイクルも違うので、フェーズ7 で**別リポジトリ**新設。今は不要。

---

## シャットダウンしても安全な理由（ユーザーの疑問への回答）
- PostgreSQL データは compose の名前付きボリューム `postgres_data` に永続化されている。
  コンテナ停止・PC シャットダウンでもタスクデータは消えず、次回そのまま続きから使える。
- よって「PC を起動しっぱなしにする必要はない」。使う時だけ立ち上げれば良い。

## 現在の起動/停止方法（フル自動化する前の暫定運用）
```powershell
# 起動
cd C:\Users\HP\my-kanban-app
docker compose up -d --build          # API + DB + 監視スタック
cd frontend; npm run dev              # フロント（別ターミナル、:5173）

# 使う: ブラウザで http://localhost:5173

# 停止
docker compose down                   # コンテナ停止（データはボリュームに残る）
# フロントは Ctrl+C
```

---

## 状態メモ（この日の終了時点）
- 両リポジトリ（my-kanban-app / portfolio）とも main、未コミット変更なし（クリーン）。
- ローカルスタックはこのドキュメント push 後に `docker compose down` で停止する予定。
- ポートフォリオの Works に my-kanban-app を GitHub リンクで掲載済み・本番デプロイ成功済み。
- 既知の非ブロッカー warning（portfolio CD）: Node.js 20 非推奨 / ubuntu-latest 移行予告。将来対応でよい。

## 参考ドキュメント
- 振り返り: [`docs/learning/2026-09-25-phase5-retrospective.md`](learning/2026-09-25-phase5-retrospective.md)
- この日の dev-log: `docs/dev-log/2026-09-25-phase5-*.md`（frontend / deploy / e2e）
