# タスク CRUD テスト スクリプト

Write-Host "=== Task CRUD Test ===" -ForegroundColor Green
Write-Host ""

$BASE_URL = "http://localhost:8080"

# 1. ユーザーを作成
Write-Host "1. Creating user..." -ForegroundColor Yellow
$user = @{
    email = "test@example.com"
    password = "password123"
    display_name = "Test User"
} | ConvertTo-Json
$userResp = Invoke-WebRequest -Uri "$BASE_URL/users" -Method Post -Body $user -ContentType "application/json"
$userId = ($userResp.Content | ConvertFrom-Json).id
Write-Host "User ID: $userId" -ForegroundColor Green

# 2. タスクを作成
Write-Host ""
Write-Host "2. Creating task..." -ForegroundColor Yellow
$task = @{
    user_id = $userId
    title = "Buy groceries"
    description = "Milk, eggs, bread"
    estimated_minutes = 30
    due_date = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
} | ConvertTo-Json
$taskResp = Invoke-WebRequest -Uri "$BASE_URL/tasks" -Method Post -Body $task -ContentType "application/json"
$taskId = ($taskResp.Content | ConvertFrom-Json).id
Write-Host "Task ID: $taskId" -ForegroundColor Green
Write-Host ($taskResp.Content | ConvertFrom-Json | ConvertTo-Json)

# 3. タスクを ID で取得
Write-Host ""
Write-Host "3. Getting task by ID..." -ForegroundColor Yellow
$getResp = Invoke-WebRequest -Uri "$BASE_URL/tasks/$taskId" -Method Get
Write-Host ($getResp.Content | ConvertFrom-Json | ConvertTo-Json)

# 4. タスクを更新
Write-Host ""
Write-Host "4. Updating task..." -ForegroundColor Yellow
$updateTask = @{
    title = "Buy groceries (updated)"
    actual_minutes = 25
    status = "in_progress"
} | ConvertTo-Json
$updateResp = Invoke-WebRequest -Uri "$BASE_URL/tasks/$taskId" -Method Patch -Body $updateTask -ContentType "application/json"
Write-Host ($updateResp.Content | ConvertFrom-Json | ConvertTo-Json)

# 5. タスクを完了
Write-Host ""
Write-Host "5. Completing task..." -ForegroundColor Yellow
$completeResp = Invoke-WebRequest -Uri "$BASE_URL/tasks/$taskId/complete" -Method Patch
Write-Host ($completeResp.Content | ConvertFrom-Json | ConvertTo-Json)

# 6. 別のタスクを作成してから削除テスト
Write-Host ""
Write-Host "6. Creating another task for deletion test..." -ForegroundColor Yellow
$task2 = @{
    user_id = $userId
    title = "Task to delete"
    description = "This will be deleted"
} | ConvertTo-Json
$task2Resp = Invoke-WebRequest -Uri "$BASE_URL/tasks" -Method Post -Body $task2 -ContentType "application/json"
$taskId2 = ($task2Resp.Content | ConvertFrom-Json).id
Write-Host "Task ID: $taskId2" -ForegroundColor Green

# 7. タスクを削除
Write-Host ""
Write-Host "7. Deleting task..." -ForegroundColor Yellow
$deleteResp = Invoke-WebRequest -Uri "$BASE_URL/tasks/$taskId2" -Method Delete
Write-Host "Status: $($deleteResp.StatusCode)" -ForegroundColor Green

# 8. 削除後確認（404を期待）
Write-Host ""
Write-Host "8. Verifying deletion (should get 404)..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "$BASE_URL/tasks/$taskId2" -Method Get -ErrorAction Stop
    Write-Host "ERROR: Task still exists!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "Confirmed: Task deleted (404)" -ForegroundColor Green
    } else {
        Write-Host "Unexpected error: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

# 9. 全タスク一覧を表示
Write-Host ""
Write-Host "9. Listing all tasks..." -ForegroundColor Yellow
$listResp = Invoke-WebRequest -Uri "$BASE_URL/tasks" -Method Get
Write-Host ($listResp.Content | ConvertFrom-Json | ConvertTo-Json)

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Green
