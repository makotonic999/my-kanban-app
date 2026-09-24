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

Write-Host ""
if ($fail -eq 0) {
    Write-Host "=== All auth checks passed ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== $fail check(s) FAILED ===" -ForegroundColor Red
    exit 1
}
