# SLO / エラー予算 定義書

## 概要

このドキュメントはKanban APIのSLO（Service Level Objective）と
エラー予算（Error Budget）の定義・運用方針を記述します。

---

## SLI / SLO 定義

### SLO 1: 可用性（Availability）

| 項目 | 内容 |
|------|------|
| **SLI** | 全リクエストのうち、5xx以外で返ったリクエストの割合 |
| **SLO** | 99.9%（月間ダウンタイム許容: 約43.8分） |
| **計測窓** | 30日間ローリング |
| **Prometheusメトリクス** | `job:slo_availability:ratio5m` / `ratio1h` / `ratio24h` |

**計算式:**
```promql
1 - (
  sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)
  /
  sum(rate(http_requests_total[5m])) by (job)
)
```

---

### SLO 2: レイテンシ（Latency）

| 項目 | 内容 |
|------|------|
| **SLI** | 500ms以内に完了したリクエストの割合（p95相当） |
| **SLO** | 95%（95%のリクエストが500ms以内） |
| **計測窓** | 5分間ローリング |
| **Prometheusメトリクス** | `job:slo_latency:ratio5m` / `ratio1h` / `ratio24h` |

**計算式:**
```promql
sum(rate(http_request_duration_seconds_bucket{path!="/metrics", le="0.5"}[5m])) by (job)
/
sum(rate(http_request_duration_seconds_count{path!="/metrics"}[5m])) by (job)
```

---

## エラー予算

### 考え方

- **月間エラー予算** = `(1 - SLO) × 30日間` = `0.1% × 43,200分` ≈ 43.8分
- エラーが発生しない期間はエラー予算が回復する
- エラー予算が枯渇した場合は、新機能リリースを停止してリライアビリティ改善を優先する

### Burn Rate（消費速度）

`burn_rate = 実際のエラーレート / 許容エラーレート(0.1%)`

| Burn Rate | 意味 |
|-----------|------|
| 1.0 | 月間ちょうどSLOギリギリの速度で消費 |
| 14.0 | 1時間で月間予算の2%を消費（Critical） |
| 6.0 | 6時間で月間予算の5%を消費（Warning） |
| 3.0 | 24時間で月間予算の10%を消費（Info） |

---

## アラート定義

Google SRE Workbookの**Multi-window, Multi-burn-rate**手法を採用。

| アラート名 | 条件 | for | 重要度 |
|-----------|------|-----|--------|
| `ErrorBudgetBurnCritical` | burn_rate_1h > 14 AND burn_rate_6h > 14 | 2分 | critical |
| `ErrorBudgetBurnHigh` | burn_rate_1h > 6 AND burn_rate_6h > 6 | 10分 | warning |
| `ErrorBudgetBurnLow` | burn_rate_6h > 3 AND burn_rate_24h > 3 | 30分 | info |
| `LatencySLOViolation` | p95 > 500ms | 5分 | warning |
| `LatencyP99High` | p99 > 1000ms | 5分 | warning |
| `AvailabilitySLOViolation` | 可用性 < 99.9% | 5分 | critical |

### Multi-windowを採用する理由

単一ウィンドウのアラートは以下の問題がある:
- **短い窓（5分）**: 瞬間的なスパイクで誤検知が多い
- **長い窓（1時間）**: 問題の検知が遅い

2つの窓を AND 条件にすることで、**速い検知**と**誤検知の抑制**を両立する。

---

## Grafanaダッシュボード

`grafana-dashboard.json` の `SLO / Error Budget` セクションに以下のパネルが含まれる:

| パネル | 説明 |
|--------|------|
| 可用性 SLO ゲージ | 直近5分の可用性（赤: <99.5%, 黄: <99.9%, 緑: >=99.9%） |
| レイテンシ SLO ゲージ | p95 < 500ms の達成率（赤: <90%, 黄: <95%, 緑: >=95%） |
| エラー予算消費速度 ゲージ | 現在のburn rate（14以上でCritical、6以上でWarning） |
| 消費速度の推移 | 1h / 6h / 24h burn rateの時系列グラフ |

---

## 関連ファイル

| ファイル | 説明 |
|----------|------|
| `slo_rules.yml` | Prometheus Recording Rules（SLI計算） |
| `alert_rules.yml` | Prometheus Alerting Rules（SLOアラート） |
| `prometheus.yml` | Prometheusスクレイプ・ルール設定 |
| `grafana-dashboard.json` | Grafanaダッシュボード定義 |

---

## 参考

- [Google SRE Book - Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
- [Google SRE Workbook - Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
