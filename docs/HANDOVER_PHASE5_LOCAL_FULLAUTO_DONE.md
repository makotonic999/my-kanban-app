# 引継ぎドキュメント - 2026-09-28（ローカルのフル自動化 完了 / 次回: 日々使い or 機能拡張）

> この日は、前回「次回やること」に据えていた**ローカル環境のフル自動化を完了**した。
> フロントをコンテナ化し、compose をコア（db+api+frontend）と監視に分割、全サービスに
> `restart: unless-stopped` を付与。実起動・ブラウザ表示まで確認済み。
> **これで「PC 起動 → Docker 自動起動 → アプリ自動復帰」がコマンドなしで成立する状態になった。**

---

## 現在地

- フェーズ1〜4: 完了 ✅
- **フェーズ5（Web フロント）**: UI / JWT / CORS / ホスティング plan / デプロイ経路 / ローカル E2E /
  **ローカルのフル自動化** まで完了 ✅
  - 残: 実 `terraform apply`（課金のため保留）、独自ドメイン+ACM、タグ UI・期日/見積もり入力
- フェーズ6（AI）/ 7（モバイル）: 未着手

### この日の成果（フル自動化）
- 新規: `frontend/Dockerfile.dev`（Vite dev server コンテナ、ホットリロード）
- 新規: `docker-compose.observability.yml`（jaeger/prometheus/grafana を分離）
- 変更: `docker-compose.yml`（コア db+api+frontend、全 `restart: unless-stopped`、監視系除去）
- 変更: `frontend/vite.config.ts`（`host:true` / `usePolling` / proxy target を `VITE_DEV_PROXY_TARGET` で切替）
- 変更: `README.md`（「ローカル環境（環境1）」「3環境分離」節を追加）
- dev-log: `docs/dev-log/2026-09-28-phase5-local-fullauto.md`

### 検証済みエビデンス
- `docker compose config`: コア=3サービス / オーバーレイ併用=6サービス（両方 exit 0）。
- 実起動: フロントイメージ Built、db Healthy → api/frontend Started、`docker compose ps` で 3 Up。
- `docker inspect` で 3 コンテナとも `restart=unless-stopped`。ブラウザ http://localhost:5173 表示 OK。

---

## 日々の使い方（ここだけ読めば使える）

```powershell
cd C:\Users\HP\my-kanban-app

# 通常はコマンド不要。PC 起動 → Docker 自動起動 → コンテナ自動復帰。
# ブラウザで http://localhost:5173 を開くだけ。

# もし止まっていたら（初回や down 後）
docker compose up -d --build     # 以降は自動復帰

# 監視（jaeger/prometheus/grafana）も見たい時だけ
docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d

# 完全に止める（次回 PC 起動でも復帰しない）
docker compose down
```

- Docker Desktop の自動起動は有効化済み（ユーザー設定）。
- データは `postgres_data` ボリュームに永続化。**シャットダウンしてもタスクは消えない**。
- 監視オーバーレイは**単独起動しない**（必ずコアに `-f` で重ねる。prometheus が `api:8080` を見るため）。

---

## 次回やること（候補・未決定）

前回のような「決定済みの一手」はまだ無い。次のいずれかから選ぶ想定。

1. **日々使ってデータを貯める（推奨・準備フェーズ）**
   - フェーズ6（AI 年間振り返り）の本丸は「タスクログを貯める」こと。使うこと自体が次の準備。
2. **フロントの伸びしろ（使いながら洗い出す）**
   - タグ UI（バックエンドに tag CRUD あり・フロント未実装）。
   - 期日（`due_date`）・見積もり時間（`estimated_minutes`）の入力欄（型定義には既に存在）。
   - 自動 E2E（Playwright / Cypress）を CI に組み込む。
3. **フェーズ5 の残り（課金要判断）**
   - 実 `terraform apply`（56 リソース）→ 実デモ → `destroy`。**課金発生**のため実施は要判断。
   - apply 後、GitHub Variables（`FRONTEND_BUCKET` / `FRONTEND_DISTRIBUTION_ID` / `VITE_API_BASE_URL`）
     登録 → CD 実走確認。独自ドメイン + ACM。
4. **フェーズ6 の下ごしらえ**
   - AI が集計しやすい DB 構造・クエリへのリファクタ、大量ダミーデータでの集計最適化検討。

---

## 3 環境の分離（設計・再掲）
| 環境 | 目的 | フロント | バックエンド | DB | 分け方 |
|---|---|---|---|---|---|
| 1. ローカル | 日々使う・データ蓄積 | compose 内 Vite | compose の Go API | compose の Postgres（永続ボリューム） | `docker-compose.yml` |
| 2. AWS 版 | Web 公開 | S3+CloudFront | ECS Fargate | RDS | `terraform/` |
| 3. モバイル版 | 将来 Google Play | Flutter/RN 別アプリ | AWS 版 API を共用 | AWS 版 RDS 共用 | 別リポジトリ（フェーズ7） |

- 環境はブランチで分けない。**コードは 1 つ、設定で分ける**。
- ローカル/AWS は同じソース。違いは設定（compose vs terraform）と環境変数だけ。
- モバイルは言語・ツールチェーンが違うのでフェーズ7 で別リポジトリ新設。今は不要。

---

## 状態メモ（この日の終了時点）
- ブランチ `docs/handover-local-fullauto` 上で作業・コミット。main への直接コミットはしていない。
- ローカルスタックは起動中。シャットダウンしても `restart: unless-stopped` + Docker 自動起動で次回復帰する。
- （必要なら）このブランチを push して PR 化 → main マージで区切り。

## 参考ドキュメント
- この日の dev-log: [`docs/dev-log/2026-09-28-phase5-local-fullauto.md`](dev-log/2026-09-28-phase5-local-fullauto.md)
- 前回引継ぎ（自動化の設計判断の経緯）: [`docs/HANDOVER_PHASE5_LOCAL_FULLAUTO.md`](HANDOVER_PHASE5_LOCAL_FULLAUTO.md)
- フェーズ5 振り返り: [`docs/learning/2026-09-25-phase5-retrospective.md`](learning/2026-09-25-phase5-retrospective.md)
