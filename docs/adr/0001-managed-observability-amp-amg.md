# ADR-0001: 本番オブザーバビリティに AMP + Amazon Managed Grafana を採用

- ステータス: Accepted（コード化のみ。実 `apply` はフロント完成後）
- 日付: 2026-09-24
- 関連: フェーズ4「本番環境への SRE 設定反映」

## コンテキスト

フェーズ2でローカル（docker-compose）向けに Prometheus + Grafana + SLO/アラートルール
（Google SRE Workbook の multi-window / multi-burn-rate）を整備済み。
フェーズ4で ECS Fargate へ本番配置するにあたり、この観測性資産を AWS 上でどう再現するかを決める。

前提:
- ローカルのルール資産（`slo_rules.yml` / `alert_rules.yml`）を捨てたくない。
- アプリはステートレスで水平スケール前提（複数タスク）。
- 学習/ポートフォリオ用途。実 `apply` は必要時のみ、使わない時は `destroy` で固定費を止める。

## 検討した選択肢

### 案A: Amazon Managed Prometheus (AMP) + Amazon Managed Grafana (AMG) ← 採用
- ECS の ADOT sidecar が `/metrics` をスクレイプし AMP に remote_write。
- 既存の PromQL ルールを AMP のルールグループにそのまま登録。
- Grafana は AMG（マネージド）。AMP をデータソースに。
- 長所: 既存 PromQL 資産を無改変で流用。マネージドで運用負荷小。スケールしても中央集約。
- 短所: 課金（AMP は取り込み/クエリ量、AMG はユーザー単位）。

### 案B: Prometheus/Grafana も Fargate に自前デプロイ
- 長所: 追加マネージド費用なし。
- 短所: 自前運用（可用性・ストレージ永続化・スケール）の負担。複数タスク時に「どこにメトリクスがあるか」問題。

### 案C: CloudWatch Container Insights 主軸
- 長所: AWS ネイティブ、構成要素が少ない。
- 短所: 既存の PromQL ベース SLO 資産を Metric Math / Alarm に**翻訳が必要**（資産が活きない）。

## 決定

**案A** を採用。理由:
1. フェーズ2の PromQL 資産（SLI/SLO/burn-rate）を**そのまま活かせる**のが最大の価値。
2. ステートレス・水平スケール前提のアプリと、中央集約型の AMP は相性が良い。
3. マネージドにより自前運用の負担を避け、SRE の本質（SLO/アラート設計）に集中できる。
4. `apply`/`destroy` 前提の運用でコストを制御でき、これまでの段階構成と一貫。

## 構成（Terraform）

```
ECS task
 ├─ api container            (:8080 /metrics)
 └─ adot-collector sidecar   prometheus receiver -> prometheusremotewrite (sigv4auth, aps)
                                   │
                                   ▼
                          AMP workspace  ── rule group (SLO recording + alerts)
                                   │
                                   ▼
                          Amazon Managed Grafana (AWS SSO)  ── data source: AMP
```

- `terraform/amp.tf`: ワークスペース + ルールグループ（`amp_rules.yml`）。
- `terraform/adot.tf`: ADOT collector 設定（SSM 経由で sidecar に注入）。
- `terraform/grafana.tf`: AMG ワークスペース + AMP クエリ用ロール（`enable_grafana` でトグル）。
- IAM: タスクロールに `aps:RemoteWrite`、Grafana ロールに `aps:QueryMetrics` 等。

## トレードオフ / 既知の割り切り

- **ルール資産が二重管理**: ローカル用（`slo_rules.yml`/`alert_rules.yml`）と AMP 用（`amp_rules.yml`）が別ファイル。
  AMP は「単一の groups: リスト」を要求するため結合版を用意した。将来は片方から自動生成するのが望ましい。
- **アラート通知先が未接続**: AMP の alertmanager 連携（SNS 等）は未設定。ルール評価まで。
- **KMS は既定キー / 一部 `resources = "*"`**: List/Describe 系 API の制約による。本番では CMK と条件で厳密化。
- **AMG は AWS SSO 認証**: 既存の IAM Identity Center 前提。ユーザー割り当ては手動 or 別途コード化。

## 結果

- `terraform validate` = Success、`terraform plan` = 48 to add / 0 / 0（AMP/ADOT/AMG で +9）。
- 実 `apply` は未実施（課金なし）。フロント完成後にデモ用途で apply→destroy する。
