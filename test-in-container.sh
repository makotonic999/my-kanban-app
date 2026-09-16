#!/bin/sh
# コンテナ内で実行するテストスクリプト

echo "=== API Metrics Test (Container) ==="
echo ""
echo "Making 10 requests to generate metrics..."

for i in $(seq 1 10); do
    echo "Request $i..."
    curl -s http://api:8080/tasks > /dev/null
    sleep 0.5
done

echo ""
echo "Fetching metrics from /metrics endpoint..."
curl -s http://api:8080/metrics | grep -E "^http_request_duration_seconds_bucket|^http_requests_total" | head -20

echo ""
echo "Test complete."
