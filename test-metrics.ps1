# メトリクス確認用スクリプト (PowerShell)

Write-Host "=== Prometheus Metrics Test ===" -ForegroundColor Green
Write-Host ""

Write-Host "1. Getting metrics from /metrics endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/metrics" -Method Get
    $metrics = $response.Content -split "`n" | Where-Object { $_ -match "^http_request_duration_seconds|^http_requests_total|^http_request_size_bytes|^http_response_size_bytes" } | Select-Object -First 20
    $metrics | ForEach-Object { Write-Host $_ }
} catch {
    Write-Host "Failed to connect to API. Is it running on port 8080?" -ForegroundColor Red
}

Write-Host ""
Write-Host "2. Making sample requests to generate metrics..." -ForegroundColor Yellow

# サンプルリクエスト: GET /tasks
Write-Host "GET /tasks" -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/tasks" -Method Get
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Request failed: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "3. Checking metrics after requests..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/metrics" -Method Get
    $metrics = $response.Content -split "`n" | Where-Object { $_ -match "^http_request_duration_seconds_bucket|^http_requests_total" } | Select-Object -First 15
    $metrics | ForEach-Object { Write-Host $_ }
} catch {
    Write-Host "Failed to get metrics" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Green
