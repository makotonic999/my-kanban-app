# AWS Distro for OpenTelemetry (ADOT) Collector の設定。
# api コンテナの /metrics を Prometheus 形式でスクレイプし、AMP へ remote_write する。
# 設定は SSM Parameter に置き、sidecar は AOT_CONFIG_CONTENT 環境変数から読み込む。

locals {
  adot_config = <<-YAML
    receivers:
      prometheus:
        config:
          global:
            scrape_interval: 15s
            external_labels:
              service: kanban-api
          scrape_configs:
            - job_name: my-kanban-app
              scrape_interval: 5s
              metrics_path: /metrics
              static_configs:
                - targets: [localhost:${var.app_container_port}]
                  labels:
                    instance: api-server
                    service: kanban-api

    processors:
      batch:
        timeout: 30s

    exporters:
      prometheusremotewrite:
        endpoint: "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
        auth:
          authenticator: sigv4auth

    extensions:
      sigv4auth:
        region: ${var.region}
        service: aps

    service:
      extensions: [sigv4auth]
      pipelines:
        metrics:
          receivers: [prometheus]
          processors: [batch]
          exporters: [prometheusremotewrite]
  YAML
}

resource "aws_ssm_parameter" "adot_config" {
  name  = "/${local.name}/adot/config"
  type  = "String"
  value = local.adot_config
  tier  = "Advanced" # 4KB を超える可能性があるため Advanced 層
  tags  = { Name = "${local.name}-adot-config" }
}
