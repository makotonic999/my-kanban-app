# ユーザー作成
$user = @{email="tag-test@example.com"; password="pass"} | ConvertTo-Json
$userResp = Invoke-WebRequest -Uri "http://localhost:8080/users" -Method Post -Body $user -ContentType "application/json"
$userId = ($userResp.Content | ConvertFrom-Json).id
Write-Host "User: $userId" -ForegroundColor Green

# タグ作成 1
Write-Host ""
Write-Host "Creating tag 1..." -ForegroundColor Yellow
$tag1 = @{user_id=$userId; name="Work"} | ConvertTo-Json
$tag1Resp = Invoke-WebRequest -Uri "http://localhost:8080/tags" -Method Post -Body $tag1 -ContentType "application/json"
$tag1Id = ($tag1Resp.Content | ConvertFrom-Json).id
Write-Host "Tag 1 ID: $tag1Id"
$tag1Resp.Content | ConvertFrom-Json

# タグ作成 2
Write-Host ""
Write-Host "Creating tag 2..." -ForegroundColor Yellow
$tag2 = @{user_id=$userId; name="Personal"} | ConvertTo-Json
$tag2Resp = Invoke-WebRequest -Uri "http://localhost:8080/tags" -Method Post -Body $tag2 -ContentType "application/json"
$tag2Id = ($tag2Resp.Content | ConvertFrom-Json).id
Write-Host "Tag 2 ID: $tag2Id"
$tag2Resp.Content | ConvertFrom-Json

# タグ一覧
Write-Host ""
Write-Host "Listing tags..." -ForegroundColor Yellow
$listResp = Invoke-WebRequest -Uri "http://localhost:8080/users/$userId/tags" -Method Get
$listResp.Content | ConvertFrom-Json

# タグ削除
Write-Host ""
Write-Host "Deleting tag 1..." -ForegroundColor Yellow
$delResp = Invoke-WebRequest -Uri "http://localhost:8080/tags/$tag1Id" -Method Delete
Write-Host "Status: $($delResp.StatusCode)" -ForegroundColor Green

# 削除後確認
Write-Host ""
Write-Host "Listing tags after deletion..." -ForegroundColor Yellow
$listResp = Invoke-WebRequest -Uri "http://localhost:8080/users/$userId/tags" -Method Get
$listResp.Content | ConvertFrom-Json
