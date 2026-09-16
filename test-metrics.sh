#!/bin/bash
# メトリクス確認用スクリプト

echo "=== Prometheus Metrics Test ==="
echo ""

# Prometheus エンドポイントからメトリクスを取得
echo "1. Getting metrics from /metrics endpoint..."
curl -s http://localhost:8080/metrics | grep -E "^http_request_duration_seconds|^http_requests_total|^http_request_size_bytes|^http_response_size_bytes" | head -20

echo ""
echo "2. Making sample requests to generate metrics..."

# サンプルリクエストを送信
echo "POST /users"
curl -s -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com"}' | jq . || echo "Failed"

echo ""
echo "GET /tasks"
curl -s -X GET http://localhost:8080/tasks | jq . || echo "Failed"

echo ""
echo "=== Checking metrics after requests ==="
curl -s http://localhost:8080/metrics | grep "^http_" | head -20
