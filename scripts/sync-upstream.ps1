# =============================================================================
# sync-upstream.ps1 — 拉取上游 Gridea Pro 源码并构建绿色便携版（Windows）
# =============================================================================
# 用法：
#   .\scripts\sync-upstream.ps1 [-Ref "v1.0.0"]
#   .\scripts\sync-upstream.ps1 -Ref "main"
#
# 环境变量（可选）：
#   $env:GH_OAUTH_CLIENT_ID       — GitHub OAuth 客户端 ID
#   $env:GH_OAUTH_CLIENT_SECRET   — GitHub OAuth 客户端密钥
#   $env:NETLIFY_CLIENT_ID        — Netlify OAuth 客户端 ID
#   $env:NETLIFY_CLIENT_SECRET    — Netlify OAuth 客户端密钥
#   $env:VERCEL_CLIENT_ID         — Vercel OAuth 客户端 ID
#   $env:VERCEL_CLIENT_SECRET     — Vercel OAuth 客户端密钥
# =============================================================================
param(
    [string]$Ref = "main",
    [string]$UpstreamRepo = "https://github.com/Gridea-Pro/gridea-pro.git"
)

$ErrorActionPreference = "Stop"

# ----- 常量 -----
$AppName     = "Gridea Pro"
$BinSlug     = "gridea-pro"
$Prefix      = "gridea-pro-portable"
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir     = Split-Path -Parent $ScriptDir
$SourceDir   = Join-Path $RootDir "source"
$OutputDir   = Join-Path $RootDir "dist"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Gridea Pro Portable — 同步 & 构建 (Windows)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "上游仓库: $UpstreamRepo"
Write-Host "目标 ref: $Ref"
Write-Host "源码目录: $SourceDir"
Write-Host "输出目录: $OutputDir"
Write-Host ""

# ----- 第 1 步：拉取源码 -----
Write-Host "[1/6] 拉取上游源码..." -ForegroundColor Yellow
if (Test-Path $SourceDir) {
    Write-Host "  源码目录已存在，清理后重新克隆..."
    Remove-Item -Recurse -Force $SourceDir
}

if ($Ref -eq "main" -or $Ref -eq "master") {
    git clone --depth 1 $UpstreamRepo $SourceDir
} else {
    $cloneResult = git clone --depth 1 --branch $Ref $UpstreamRepo $SourceDir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  无法直接克隆 ref '$Ref'，尝试完整克隆后切换..."
        git clone $UpstreamRepo $SourceDir
        Push-Location $SourceDir
        git checkout $Ref
        Pop-Location
    }
}

Push-Location $SourceDir
$CommitHash = (git rev-parse --short HEAD)
Pop-Location
Write-Host "  ✔ 源码已就绪（commit: $CommitHash）" -ForegroundColor Green
Write-Host ""

# ----- 第 2 步：检测版本 -----
Write-Host "[2/6] 检测版本号..." -ForegroundColor Yellow
$Version = $Ref
if ($Version.StartsWith("v")) {
    $VersionNum = $Version.Substring(1)
} else {
    $VersionNum = "0.0.0-dev"
}
Write-Host "  版本: $Version（数字: $VersionNum）"
Write-Host ""

# ----- 第 3 步：修补 wails.json -----
Write-Host "[3/6] 修补 wails.json productVersion..." -ForegroundColor Yellow
Push-Location $SourceDir
$wailsJson = Get-Content "wails.json" -Raw | ConvertFrom-Json
if (-not $wailsJson.info) {
    $wailsJson | Add-Member -NotePropertyName "info" -NotePropertyValue @{}
}
$wailsJson.info.productVersion = $VersionNum
$wailsJson | ConvertTo-Json -Depth 10 | Set-Content "wails.json" -Encoding UTF8
Write-Host "  ✔ wails.json productVersion → $VersionNum" -ForegroundColor Green
Pop-Location
Write-Host ""

# ----- 第 4 步：安装前端依赖 -----
Write-Host "[4/6] 安装前端依赖..." -ForegroundColor Yellow
Push-Location (Join-Path $SourceDir "frontend")
npm install --legacy-peer-deps 2>$null
if ($LASTEXITCODE -ne 0) { npm install --force }
Pop-Location
Write-Host ""

# ----- 第 5 步：构建 -----
Write-Host "[5/6] 构建绿色便携版..." -ForegroundColor Yellow

# 组装 ldflags
$ldflags = "-X main.Version=$VersionNum"
if ($env:GH_OAUTH_CLIENT_ID) {
    $ldflags += " -X gridea-pro/backend/internal/service/oauth.githubClientID=$env:GH_OAUTH_CLIENT_ID"
    $ldflags += " -X gridea-pro/backend/internal/service/oauth.githubClientSecret=$env:GH_OAUTH_CLIENT_SECRET"
}
if ($env:NETLIFY_CLIENT_ID) {
    $ldflags += " -X gridea-pro/backend/internal/service/oauth.netlifyClientID=$env:NETLIFY_CLIENT_ID"
    $ldflags += " -X gridea-pro/backend/internal/service/oauth.netlifyClientSecret=$env:NETLIFY_CLIENT_SECRET"
}
if ($env:VERCEL_CLIENT_ID) {
    $ldflags += " -X gridea-pro/backend/internal/service/oauth.vercelClientID=$env:VERCEL_CLIENT_ID"
    $ldflags += " -X gridea-pro/backend/internal/service/oauth.vercelClientSecret=$env:VERCEL_CLIENT_SECRET"
}

$arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq "Arm64") { "arm64" } else { "amd64" }
Write-Host "  当前平台: windows/$arch"
Write-Host "  ldflags: $ldflags"
Write-Host ""

Push-Location $SourceDir
wails build -platform "windows/$arch" -clean -trimpath -tags portable -ldflags $ldflags
Pop-Location

# 构建 MCP 服务器
Write-Host "  构建 MCP 服务器..."
Push-Location $SourceDir
$env:GOOS = "windows"
$env:GOARCH = $arch
$env:CGO_ENABLED = "0"
go build -tags portable -ldflags="-s -w -X main.Version=$VersionNum" -o "build/bin/$BinSlug-mcp.exe" ./backend/cmd/mcp
$env:GOOS = ""
$env:GOARCH = ""
$env:CGO_ENABLED = ""
Pop-Location

Write-Host "  ✔ 构建完成" -ForegroundColor Green
Write-Host ""

# ----- 第 6 步：打包 -----
Write-Host "[6/6] 打包便携文件..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$stagingDir = Join-Path $RootDir ".staging"
if (Test-Path $stagingDir) { Remove-Item -Recurse -Force $stagingDir }
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

$buildBin = Join-Path $SourceDir "build/bin"

# 复制主程序
Copy-Item (Join-Path $buildBin "$AppName.exe") $stagingDir -Force
# 复制 MCP 服务器
$mcpPath = Join-Path $buildBin "$BinSlug-mcp.exe"
if (Test-Path $mcpPath) { Copy-Item $mcpPath $stagingDir -Force }

# 创建 .portable 标记文件
New-Item -ItemType File -Force -Path (Join-Path $stagingDir ".portable") | Out-Null

# 创建便携说明
@"
Gridea Pro Portable（绿色便携版）
=====================================
解压到任意目录即可运行，无需安装。
首次运行会在 exe 同级目录创建 gridea-pro-data/ 文件夹，
所有配置、站点数据、缓存均存放在该目录中。
不会修改注册表、不会在 AppData 中创建文件。

运行方式：双击 Gridea Pro.exe
如需迁移：整个目录拷贝到新位置即可。
"@ | Out-File -FilePath (Join-Path $stagingDir "README.txt") -Encoding UTF8

# 压缩
$output = Join-Path $OutputDir "$Prefix-windows-$arch.zip"
Compress-Archive -Path (Join-Path $stagingDir "*") -DestinationPath $output -Force

# 清理暂存
Remove-Item -Recurse -Force $stagingDir

Write-Host "  ✔ 输出文件：" -ForegroundColor Green
Get-ChildItem $OutputDir | Format-Table Name, Length
Write-Host ""

# ----- 生成校验文件 -----
Write-Host "生成 SHA256SUMS..." -ForegroundColor Yellow
Push-Location $OutputDir
$hashes = Get-ChildItem -File | Where-Object { $_.Name -ne "SHA256SUMS" } | ForEach-Object {
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    "$hash  $($_.Name)"
}
$hashes | Out-File -FilePath "SHA256SUMS" -Encoding ASCII -NoNewline:$false
Write-Host "  ✔ SHA256SUMS 已生成" -ForegroundColor Green
Get-Content "SHA256SUMS"
Pop-Location

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " ✔ 绿色便携版构建完成！" -ForegroundColor Green
Write-Host " 输出目录: $OutputDir" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
