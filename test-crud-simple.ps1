# ユーザー作成
$user = @{email="test3@example.com"; password="pass"} | ConvertTo-Json
$userResp = Invoke-WebRequest -Uri "http://localhost:8080/users" -Method Post -Body $user -ContentType "application/json"
$userId = ($userResp.Content | ConvertFrom-Json).id
Write-Host "User: $userId" -ForegroundColor Green

# タスク作成
$task = @{user_id=$userId; title="Test Task"} | ConvertTo-Json
$taskResp = Invoke-WebRequest -Uri "http://localhost:8080/tasks" -Method Post -Body $task -ContentType "application/json"
$taskId = ($taskResp.Content | ConvertFrom-Json).id
Write-Host "Task: $taskId" -ForegroundColor Green

# タスク取得
Write-Host "GET /tasks/{id}:" -ForegroundColor Yellow
$getResp = Invoke-WebRequest -Uri "http://localhost:8080/tasks/$taskId" -Method Get
$getResp.Content | ConvertFrom-Json

# タスク更新
Write-Host ""
Write-Host "PATCH /tasks/{id}:" -ForegroundColor Yellow
$update = @{title="Updated Task"} | ConvertTo-Json
$patchResp = Invoke-WebRequest -Uri "http://localhost:8080/tasks/$taskId" -Method Patch -Body $update -ContentType "application/json"
$patchResp.Content | ConvertFrom-Json

# タスク削除
Write-Host ""
Write-Host "DELETE /tasks/{id}:" -ForegroundColor Yellow
$delResp = Invoke-WebRequest -Uri "http://localhost:8080/tasks/$taskId" -Method Delete
Write-Host "Status: $($delResp.StatusCode)" -ForegroundColor Green

# 確認（404を期待）
Write-Host ""
Write-Host "Verify deletion (expect 404):" -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "http://localhost:8080/tasks/$taskId" -Method Get -ErrorAction Stop
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "Confirmed deleted" -ForegroundColor Green
    }
}
