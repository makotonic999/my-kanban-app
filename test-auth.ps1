# JWT Auth integration test script
#
# Prerequisite: api / db running via docker compose.
#   docker compose up -d
# Run:
#   ./test-auth.ps1

Write-Host "=== JWT Auth Integration Test ===" -ForegroundColor Green
Write-Host ""

$BASE_URL = "http://localhost:8080"
$fail = 0

# Use a fresh unique email each run to avoid the UNIQUE(email) constraint.
$suffix = "{0}{1}" -f (Get-Random), ((Get-Date).Ticks)
if ([string]::IsNullOrWhiteSpace($suffix)) {
    Write-Host "FATAL: failed to generate unique suffix" -ForegroundColor Red
    exit 1
}
$email = "auth-$suffix@example.com"
$password = "password123"

# 1. Create user
Write-Host ("1. Creating user ({0})..." -f $email) -ForegroundColor Yellow
$userBody = @{ email = $email; password = $password; display_name = "Auth Test" } | ConvertTo-Json
$userResp = Invoke-WebRequest -Uri "$BASE_URL/users" -Method Post -Body $userBody -ContentType "application/json" -UseBasicParsing
$userId = ($userResp.Content | ConvertFrom-Json).id
Write-Host "   User ID: $userId" -ForegroundColor Green

# 2. Login -> obtain token
Write-Host ""
Write-Host "2. Logging in to obtain token..." -ForegroundColor Yellow
$loginBody = @{ email = $email; password = $password } | ConvertTo-Json
$loginResp = Invoke-WebRequest -Uri "$BASE_URL/login" -Method Post -Body $loginBody -ContentType "application/json" -UseBasicParsing
$token = ($loginResp.Content | ConvertFrom-Json).token
if ([string]::IsNullOrEmpty($token)) {
    Write-Host "   FAIL: no token returned" -ForegroundColor Red
    $fail++
} else {
    Write-Host "   OK: token received (len=$($token.Length))" -ForegroundColor Green
}

# 3. Access protected endpoint WITH valid token (expect 200)
Write-Host ""
Write-Host "3. Accessing protected GET /tasks WITH token (expect 200)..." -ForegroundColor Yellow
try {
    $okResp = Invoke-WebRequest -Uri "$BASE_URL/tasks" -Method Get -Headers @{ Authorization = "Bearer $token" } -UseBasicParsing -ErrorAction Stop
    if ($okResp.StatusCode -eq 200) {
        Write-Host "   OK: 200 with valid token" -ForegroundColor Green
    } else {
        Write-Host "   FAIL: unexpected status $($okResp.StatusCode)" -ForegroundColor Red
        $fail++
    }
} catch {
    Write-Host "   FAIL: request errored: $($_.Exception.Message)" -ForegroundColor Red
    $fail++
}

# 4. Access protected endpoint WITHOUT token (expect 401)
Write-Host ""
Write-Host "4. Accessing protected GET /tasks WITHOUT token (expect 401)..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "$BASE_URL/tasks" -Method Get -UseBasicParsing -ErrorAction Stop | Out-Null
    Write-Host "   FAIL: request succeeded but should be 401" -ForegroundColor Red
    $fail++
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 401) {
        Write-Host "   OK: 401 without token" -ForegroundColor Green
    } else {
        Write-Host "   FAIL: unexpected status $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        $fail++
    }
}

# 5. Access protected endpoint WITH invalid token (expect 401)
Write-Host ""
Write-Host "5. Accessing protected GET /tasks WITH invalid token (expect 401)..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "$BASE_URL/tasks" -Method Get -Headers @{ Authorization = "Bearer not.a.valid.jwt" } -UseBasicParsing -ErrorAction Stop | Out-Null
    Write-Host "   FAIL: request succeeded but should be 401" -ForegroundColor Red
    $fail++
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 401) {
        Write-Host "   OK: 401 with invalid token" -ForegroundColor Green
    } else {
        Write-Host "   FAIL: unexpected status $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        $fail++
    }
}

# 6. Login with wrong password (expect 401)
Write-Host ""
Write-Host "6. Logging in with wrong password (expect 401)..." -ForegroundColor Yellow
$badLogin = @{ email = $email; password = "wrong-password" } | ConvertTo-Json
try {
    Invoke-WebRequest -Uri "$BASE_URL/login" -Method Post -Body $badLogin -ContentType "application/json" -UseBasicParsing -ErrorAction Stop | Out-Null
    Write-Host "   FAIL: login succeeded but should be 401" -ForegroundColor Red
    $fail++
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 401) {
        Write-Host "   OK: 401 on wrong password" -ForegroundColor Green
    } else {
        Write-Host "   FAIL: unexpected status $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        $fail++
    }
}

# ---- Authorization (cross-user isolation) ----
# User A creates a task; User B must NOT be able to read/delete it, and must not see it in their list.

# 7. User A creates a task (owner = token user, body user_id is ignored)
Write-Host ""
Write-Host "7. User A creates a task..." -ForegroundColor Yellow
$taskBody = @{ title = "A's secret task" } | ConvertTo-Json
$taskResp = Invoke-WebRequest -Uri "$BASE_URL/tasks" -Method Post -Body $taskBody -ContentType "application/json" -Headers @{ Authorization = "Bearer $token" } -UseBasicParsing
$taskId = ($taskResp.Content | ConvertFrom-Json).id
Write-Host "   Task ID (owned by A): $taskId" -ForegroundColor Green

# 8. Create User B and log in
Write-Host ""
Write-Host "8. Creating User B and logging in..." -ForegroundColor Yellow
$emailB = "authb-$suffix@example.com"
$userBodyB = @{ email = $emailB; password = $password; display_name = "Auth Test B" } | ConvertTo-Json
Invoke-WebRequest -Uri "$BASE_URL/users" -Method Post -Body $userBodyB -ContentType "application/json" -UseBasicParsing | Out-Null
$loginBodyB = @{ email = $emailB; password = $password } | ConvertTo-Json
$loginRespB = Invoke-WebRequest -Uri "$BASE_URL/login" -Method Post -Body $loginBodyB -ContentType "application/json" -UseBasicParsing
$tokenB = ($loginRespB.Content | ConvertFrom-Json).token
Write-Host "   User B token received (len=$($tokenB.Length))" -ForegroundColor Green

# 9. User B tries to GET User A's task (expect 404)
Write-Host ""
Write-Host "9. User B GET A's task (expect 404)..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "$BASE_URL/tasks/$taskId" -Method Get -Headers @{ Authorization = "Bearer $tokenB" } -UseBasicParsing -ErrorAction Stop | Out-Null
    Write-Host "   FAIL: User B could read User A's task!" -ForegroundColor Red
    $fail++
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "   OK: 404 (B cannot read A's task)" -ForegroundColor Green
    } else {
        Write-Host "   FAIL: unexpected status $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        $fail++
    }
}

# 10. User B tries to DELETE User A's task (expect 404)
Write-Host ""
Write-Host "10. User B DELETE A's task (expect 404)..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri "$BASE_URL/tasks/$taskId" -Method Delete -Headers @{ Authorization = "Bearer $tokenB" } -UseBasicParsing -ErrorAction Stop | Out-Null
    Write-Host "   FAIL: User B could delete User A's task!" -ForegroundColor Red
    $fail++
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "   OK: 404 (B cannot delete A's task)" -ForegroundColor Green
    } else {
        Write-Host "   FAIL: unexpected status $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        $fail++
    }
}

# 11. User B's task list must not contain A's task
Write-Host ""
Write-Host "11. User B list does not contain A's task..." -ForegroundColor Yellow
$listRespB = Invoke-WebRequest -Uri "$BASE_URL/tasks" -Method Get -Headers @{ Authorization = "Bearer $tokenB" } -UseBasicParsing
$listB = $listRespB.Content | ConvertFrom-Json
$leaked = @($listB | Where-Object { $_.id -eq $taskId })
if ($leaked.Count -eq 0) {
    Write-Host "   OK: A's task not visible to B (B has $($listB.Count) task(s))" -ForegroundColor Green
} else {
    Write-Host "   FAIL: A's task leaked into B's list!" -ForegroundColor Red
    $fail++
}

# 12. User A can still read/delete their own task (expect 200 then 204)
Write-Host ""
Write-Host "12. User A reads then deletes own task (expect 200, 204)..." -ForegroundColor Yellow
try {
    $aGet = Invoke-WebRequest -Uri "$BASE_URL/tasks/$taskId" -Method Get -Headers @{ Authorization = "Bearer $token" } -UseBasicParsing -ErrorAction Stop
    $aDel = Invoke-WebRequest -Uri "$BASE_URL/tasks/$taskId" -Method Delete -Headers @{ Authorization = "Bearer $token" } -UseBasicParsing -ErrorAction Stop
    if ($aGet.StatusCode -eq 200 -and $aDel.StatusCode -eq 204) {
        Write-Host "   OK: A can access own task (200) and delete it (204)" -ForegroundColor Green
    } else {
        Write-Host "   FAIL: unexpected statuses get=$($aGet.StatusCode) del=$($aDel.StatusCode)" -ForegroundColor Red
        $fail++
    }
} catch {
    Write-Host "   FAIL: owner request errored: $($_.Exception.Message)" -ForegroundColor Red
    $fail++
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "=== All auth checks passed ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== $fail check(s) FAILED ===" -ForegroundColor Red
    exit 1
}
