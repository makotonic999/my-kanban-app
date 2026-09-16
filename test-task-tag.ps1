# ユーザー作成
$user = @{email="task-tag-test@example.com"; password="pass"} | ConvertTo-Json
$userResp = Invoke-WebRequest -Uri "http://localhost:8080/users" -Method Post -Body $user -ContentType "application/json"
$userId = ($userResp.Content | ConvertFrom-Json).id
Write-Host "User: $userId" -ForegroundColor Green

# タスク作成
$task = @{user_id=$userId; title="Integrate Tags"} | ConvertTo-Json
$taskResp = Invoke-WebRequest -Uri "http://localhost:8080/tasks" -Method Post -Body $task -ContentType "application/json"
$taskId = ($taskResp.Content | ConvertFrom-Json).id
Write-Host "Task: $taskId" -ForegroundColor Green

# タグ作成
$tag1 = @{user_id=$userId; name="Feature"} | ConvertTo-Json
$tag1Resp = Invoke-WebRequest -Uri "http://localhost:8080/tags" -Method Post -Body $tag1 -ContentType "application/json"
$tag1Id = ($tag1Resp.Content | ConvertFrom-Json).id
Write-Host "Tag 1: $tag1Id" -ForegroundColor Green

$tag2 = @{user_id=$userId; name="Backend"} | ConvertTo-Json
$tag2Resp = Invoke-WebRequest -Uri "http://localhost:8080/tags" -Method Post -Body $tag2 -ContentType "application/json"
$tag2Id = ($tag2Resp.Content | ConvertFrom-Json).id
Write-Host "Tag 2: $tag2Id" -ForegroundColor Green

# タスクにタグ追加
Write-Host ""
Write-Host "Adding tag 1 to task..." -ForegroundColor Yellow
$addTag1 = @{tag_id=$tag1Id} | ConvertTo-Json
$addResp = Invoke-WebRequest -Uri "http://localhost:8080/tasks/$taskId/tags" -Method Post -Body $addTag1 -ContentType "application/json"
Write-Host "Status: $($addResp.StatusCode)" -ForegroundColor Green

Write-Host ""
Write-Host "Adding tag 2 to task..." -ForegroundColor Yellow
$addTag2 = @{tag_id=$tag2Id} | ConvertTo-Json
$addResp2 = Invoke-WebRequest -Uri "http://localhost:8080/tasks/$taskId/tags" -Method Post -Body $addTag2 -ContentType "application/json"
Write-Host "Status: $($addResp2.StatusCode)" -ForegroundColor Green

# DB 確認
Write-Host ""
Write-Host "DB check (SELECT * FROM task_tags WHERE task_id = $taskId):" -ForegroundColor Yellow
docker exec my-kanban-app-db-1 psql -U kanban -d kanban_dev -c "SELECT * FROM task_tags WHERE task_id = $taskId"

# タスクからタグ削除
Write-Host ""
Write-Host "Removing tag 1 from task..." -ForegroundColor Yellow
$delResp = Invoke-WebRequest -Uri "http://localhost:8080/tasks/$taskId/tags/$tag1Id" -Method Delete
Write-Host "Status: $($delResp.StatusCode)" -ForegroundColor Green

# DB 確認
Write-Host ""
Write-Host "DB check after deletion:" -ForegroundColor Yellow
docker exec my-kanban-app-db-1 psql -U kanban -d kanban_dev -c "SELECT * FROM task_tags WHERE task_id = $taskId"
