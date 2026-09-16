# API テスト実行
Write-Host "=== Kanban API Test ===" -ForegroundColor Green

# 10回のテストリクエストを連続送信（メトリクス生成用）
Write-Host ""
Write-Host "Sending 10 test requests to generate metrics..." -ForegroundColor Yellow

for ($i = 1; $i -le 10; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:8080/tasks" -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
        Write-Host "Request $i: Status $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "Request $i: Connection failed (API may not be accessible from host)" -ForegroundColor Yellow
        break
    }
}

Write-Host ""
Write-Host "Test complete. Check Prometheus metrics at http://localhost:9090" -ForegroundColor Cyan
