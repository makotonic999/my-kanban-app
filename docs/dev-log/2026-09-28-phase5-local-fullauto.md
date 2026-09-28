# dev-log: 2026-09-28（フェーズ5 続き）— ローカル環境のフル自動化

## この日やったこと
「PC 起動 → Docker Desktop 自動起動 → KanbanApp 一式が自動復帰」を実現するため、
**フロントのコンテナ化**と **compose のコア/監視分割**を実装し、実起動まで確認した。
Docker Compose の概念（コンテナ / Compose / ネットワーク / 分割の狙い）を再確認してから着手。

## 実装
### フロントのコンテナ化（`frontend/Dockerfile.dev`・新規）
- `node:20-alpine`。`package.json` / `package-lock.json` を先に COPY → `npm ci` でレイヤキャッシュ。
- `CMD ["npm","run","dev","--","--host","0.0.0.0"]` でコンテナ外のブラウザから到達可能に。
- ソースは compose の bind mount で上書きしホットリロード。マウント無しでも起動できるよう `COPY . .` も残す。

### compose をコア構成に再編（`docker-compose.yml`）
- サービスを **db + api + frontend** の 3 つに。監視系（jaeger/prometheus/grafana）は除去。
- 全サービスに **`restart: unless-stopped`** を付与 → Docker Desktop 起動で自動復帰。
- `frontend`: `./frontend` を bind mount、`node_modules` は匿名ボリュームでコンテナ側を使用。
  `VITE_DEV_PROXY_TARGET: http://api:8080` を注入。`depends_on: api`。
- `api`: `OTEL_EXPORTER_OTLP_ENDPOINT` を `${...:-}`（既定空）に。監視なしでも起動できるように。

### 監視オーバーレイ（`docker-compose.observability.yml`・新規）
- jaeger / prometheus / grafana を分離。全て `restart: unless-stopped`。
- `api` の `OTEL_EXPORTER_OTLP_ENDPOINT: jaeger:4318` をオーバーレイで上書き。
- **単独起動禁止**（prometheus が `api:8080` をスクレイプするため、コアと同一プロジェクト/
  ネットワークで起動する必要がある）。冒頭コメントに明記。

### Vite 設定のコンテナ対応（`frontend/vite.config.ts`）
- `server.host: true`（0.0.0.0 待受）。
- `server.watch.usePolling: true`（Windows→Linux コンテナの bind mount で変更検知が効かない保険）。
- proxy `target` を `process.env.VITE_DEV_PROXY_TARGET ?? "http://localhost:8080"` に。
  コンテナは `api:8080`、ホスト直起動は `localhost:8080` を自動で使い分け。

### ドキュメント（`README.md`）
- 「🖥 ローカル環境（環境1）— フル自動化」節を新設（起動/停止、監視の重ね方、自動復帰の仕組み、
  compose 分割の理由）。
- 「🌐 3 環境の分離（設計）」節を新設（ローカル/AWS/モバイルの表と設計判断）。
- 末尾の旧ローカル手順（`docker compose up` + `npm run dev`）を新構成に更新。

## 検証エビデンス
- `docker compose config --services`: コア = `db` / `api` / `frontend`（3）= exit 0。
- オーバーレイ併用 config: `db` / `jaeger` / `api` / `frontend` / `prometheus` / `grafana`（6）= exit 0。
- マージ後 config: `api` の `OTEL_EXPORTER_OTLP_ENDPOINT = jaeger:4318` 上書き・全 6 サービスに
  `restart: unless-stopped` を確認。
- **実起動**: `docker compose up -d --build` でフロントイメージ Built、`db` Healthy → `api`/`frontend` Started。
  `docker compose ps` で 3 コンテナ Up（db healthy）、`docker inspect` で 3 つとも
  `restart=unless-stopped` を確認。ブラウザ http://localhost:5173 の表示も目視 OK。

## 運用（この日以降の使い方）
```powershell
# 日常（コマンドは基本不要。PC 起動で自動復帰）
docker compose up -d --build          # 最初の1回だけ。以降は自動
# → http://localhost:5173

# 監視も見たい時だけ
docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d

# 完全に止める（次回 PC 起動でも復帰しなくなる）
docker compose down
```
- Docker Desktop の自動起動はユーザー側で有効化済み。
- データは `postgres_data` ボリュームに永続化。停止・シャットダウンでもタスクは消えない。

## 学び / 割り切り
- **`restart: unless-stopped`** は「PC 再起動でも自動復帰、ただし明示 `down`/`stop` したものは復帰しない」。
  意図的に止めたものが勝手に復活しないので扱いやすい。
- **compose の -f 併用 = 同一プロジェクト = 同一ネットワーク**。だから分割しても prometheus は
  `api:8080` を名前解決できる。監視オーバーレイは単独起動しない運用に統一。
- **コードは 1 つ、環境は設定で分ける**方針を README に明文化（ブランチ分離はしない）。

## 次のステップ（候補）
- 日々使ってタスクログを貯める（フェーズ6 AI 機能の準備）。
- フロントの伸びしろ: タグ UI / 期日・見積もり入力欄（型は定義済み）。
- 実 `terraform apply`（課金要判断）→ 実デモ → destroy。
