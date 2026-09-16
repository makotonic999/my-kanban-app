# Prometheus メトリクス実装ガイド

## 概要

Kanban API に Prometheus メトリクスを統合し、HTTP リクエストのレイテンシ、リクエスト数、バイトサイズを計測します。

## 実装内容

### 1. メトリクス定義 (`internal/metrics/metrics.go`)

以下のメトリクスを定義：

| メトリクス | 型 | 説明 | ラベル |
|-----------|------|------|--------|
| `http_request_duration_seconds` | Histogram | HTTP リクエストのレイテンシ（秒） | method, path, status |
| `http_requests_total` | Counter | HTTP リクエストの総数 | method, path, status |
| `http_request_size_bytes` | Histogram | リクエストボディサイズ（バイト） | method, path |
| `http_response_size_bytes` | Histogram | レスポンスボディサイズ（バイト） | method, path, status |
| `db_query_duration_seconds` | Histogram | DB クエリのレイテンシ（秒） | operation, table |
| `db_queries_total` | Counter | DB クエリの総数 | operation, table, status |

### 2. ミドルウェア (`internal/middleware/metrics.go`)

`MetricsMiddleware` により、すべてのHTTPリクエスト/レスポンスに対して自動的にメトリクスが計測されます。

- **レイテンシ計測**: リクエスト処理時間を秒単位で記録
- **ステータスコードトラッキング**: HTTP ステータスコード別に集計
- **サイズ計測**: リクエスト/レスポンスのボディサイズを記録

### 3. Prometheus 設定 (`prometheus.yml`)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "my-kanban-app"
    scrape_interval: 5s  # 高頻度で取得
    metrics_path: "/metrics"
    static_configs:
      - targets: ["host.docker.internal:8080"]
```

### 4. Grafana ダッシュボード (`grafana-dashboard.json`)

以下のパネルを含む：

1. **HTTP Request Latency - Percentiles**
   - p50, p95, p99 のレイテンシを時系列グラフで可視化

2. **HTTP Request Rate**
   - メソッド、パス、ステータス別のリクエストレート

3. **Total HTTP Requests**
   - 累計リクエスト数をゲージで表示

4. **Average Request/Response Size**
   - リクエスト/レスポンスの平均サイズを棒グラフで表示

5. **Database Query Latency**
   - DB クエリの平均レイテンシを時系列グラフで可視化

## ローカル環境での動作確認

### 前提条件

- Docker Desktop が起動していること
- PostgreSQL, Prometheus, Grafana, Jaeger が docker-compose で起動していること

### セットアップ手順

1. **docker-compose で全サービスを起動**
   ```bash
   docker-compose up -d
   ```

2. **API サーバーを起動**
   ```bash
   go run cmd/api/main.go
   ```

3. **メトリクスをテスト**
   ```bash
   # PowerShell
   .\test-metrics.ps1
   
   # Bash
   ./test-metrics.sh
   ```

4. **確認URL**
   - **Prometheus**: http://localhost:9090
     - `http_request_duration_seconds` などを PromQL で検索可能
   - **Grafana**: http://localhost:3000 (admin/admin)
     - ダッシュボードをインポート
   - **Jaeger**: http://localhost:16686
     - トレースを確認

### ダッシュボードのインポート

1. Grafana にアクセス (http://localhost:3000)
2. 左メニューから **Dashboards** → **Import** を選択
3. `grafana-dashboard.json` をアップロード
4. Data source として **Prometheus** を選択
5. **Import** をクリック

## PromQL クエリ例

### HTTP レイテンシの p95/p99

```promql
# p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# p99
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

### エンドポイント別のリクエストレート

```promql
rate(http_requests_total{path="/tasks"}[5m])
```

### ステータスコード別の成功率

```promql
http_requests_total{status="200"} / ignoring(status) group_left() sum(http_requests_total)
```

### DB クエリの平均レイテンシ

```promql
rate(db_query_duration_seconds_sum[5m]) / rate(db_query_duration_seconds_count[5m])
```

## SLO 定義例

```yaml
# HTTP レイテンシ SLO
- name: "HTTP Latency"
  objective: 95  # 95% が以下の条件を満たす
  indicator_filter: 'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m])) < 0.1'  # p95 < 100ms

# エラー率 SLO
- name: "Error Rate"
  objective: 99  # 99% のリクエストが成功
  indicator_filter: 'rate(http_requests_total{status=~"5.."}[5m]) < 0.01'
```

## トラブルシューティング

### メトリクスが表示されない

1. API サーバーが `/metrics` エンドポイントを公開しているか確認
   ```bash
   curl http://localhost:8080/metrics
   ```

2. Prometheus が API をスクレイプしているか確認
   - Prometheus UI: http://localhost:9090/targets

### Grafana でデータが表示されない

1. Data source の設定を確認
   - Grafana → Configuration → Data Sources
   - Prometheus: http://prometheus:9090

2. ダッシュボードの PromQL クエリが正しいか確認

## 次のステップ

- [ ] アラート定義の追加 (AlertManager)
- [ ] SLO 監視の実装
- [ ] エラートレーシングの統合
- [ ] カスタムメトリクスの追加（例：業務メトリクス）
