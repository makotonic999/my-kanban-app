<#
.SYNOPSIS
  フロントエンド(React SPA)を S3 + CloudFront に手動デプロイする。

.DESCRIPTION
  宛先(S3 バケット / CloudFront ディストリビューション ID)は Terraform の output から
  動的に取得する。ハードコードしないことで、ランダムサフィックス付きバケット名や
  再作成にも追従できる。

  処理の流れ:
    1. terraform output から frontend_bucket / frontend_distribution_id を取得
    2. frontend を本番ビルド（tsc 型チェック + vite build）
    3. dist/ を S3 に同期（--delete で削除も反映）
    4. CloudFront のキャッシュを無効化（/*）

.PREREQUISITES
  - terraform apply 済み（フロント配信リソースが存在すること）
  - AWS プロファイル 'dev' でログイン済み（aws sso login --profile dev）
  - Node.js / npm、AWS CLI、Terraform

.EXAMPLE
  ./scripts/deploy-frontend.ps1
  ./scripts/deploy-frontend.ps1 -Profile dev -Region ap-northeast-1
#>
[CmdletBinding()]
param(
  [string]$Profile = "dev",
  [string]$Region = "ap-northeast-1"
)

$ErrorActionPreference = "Stop"

# リポジトリルート基準でパスを解決（どこから実行しても動くように）。
$repoRoot = Split-Path -Parent $PSScriptRoot
$tfDir = Join-Path $repoRoot "terraform"
$frontendDir = Join-Path $repoRoot "frontend"
$distDir = Join-Path $frontendDir "dist"

Write-Host "==> Terraform output から宛先を取得..." -ForegroundColor Cyan
Push-Location $tfDir
try {
  $bucket = (terraform output -raw frontend_bucket 2>$null)
  $distId = (terraform output -raw frontend_distribution_id 2>$null)
} finally {
  Pop-Location
}

if ([string]::IsNullOrWhiteSpace($bucket) -or [string]::IsNullOrWhiteSpace($distId)) {
  Write-Error "terraform output を取得できません。`terraform apply` 済みか、$tfDir で init 済みか確認してください。"
  exit 1
}
Write-Host "    bucket           = $bucket"
Write-Host "    distribution_id  = $distId"

Write-Host "==> フロントを本番ビルド..." -ForegroundColor Cyan
Push-Location $frontendDir
try {
  if (-not (Test-Path (Join-Path $frontendDir "node_modules"))) {
    Write-Host "    node_modules が無いため npm ci を実行..."
    npm ci
    if ($LASTEXITCODE -ne 0) { throw "npm ci に失敗しました。" }
  }
  npm run build
  if ($LASTEXITCODE -ne 0) { throw "vite build に失敗しました。" }
} finally {
  Pop-Location
}

if (-not (Test-Path $distDir)) {
  Write-Error "ビルド成果物 $distDir が見つかりません。"
  exit 1
}

Write-Host "==> S3 に同期 (s3://$bucket)..." -ForegroundColor Cyan
# --delete で S3 側の不要ファイルも削除し、dist/ と完全一致させる。
aws s3 sync $distDir "s3://$bucket" --delete --profile $Profile --region $Region
if ($LASTEXITCODE -ne 0) { Write-Error "S3 同期に失敗しました。"; exit 1 }

Write-Host "==> CloudFront キャッシュを無効化..." -ForegroundColor Cyan
$invalidationId = aws cloudfront create-invalidation `
  --distribution-id $distId `
  --paths "/*" `
  --profile $Profile `
  --query "Invalidation.Id" --output text
if ($LASTEXITCODE -ne 0) { Write-Error "キャッシュ無効化に失敗しました。"; exit 1 }
Write-Host "    invalidation id = $invalidationId"

Push-Location $tfDir
try {
  $domain = (terraform output -raw frontend_cloudfront_domain 2>$null)
} finally {
  Pop-Location
}

Write-Host ""
Write-Host "デプロイ完了。" -ForegroundColor Green
if (-not [string]::IsNullOrWhiteSpace($domain)) {
  Write-Host "公開 URL: https://$domain" -ForegroundColor Green
}
