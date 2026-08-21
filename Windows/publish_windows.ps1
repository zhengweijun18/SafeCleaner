param(
    [ValidateSet("auto", "x64", "arm64", "all")]
    [string]$Architecture = "auto"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Project = Join-Path $Root "SafeMacCleaner.Windows.csproj"
$Dist = Join-Path $Root "dist"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "未检测到 .NET 8 SDK。" -ForegroundColor Yellow
    Write-Host "请安装 .NET 8 SDK 后再次运行。"
    Start-Process "https://dotnet.microsoft.com/download/dotnet/8.0"
    exit 1
}

New-Item -ItemType Directory -Force -Path $Dist | Out-Null

function Publish-One([string]$rid) {
    Write-Host "构建 $rid ..." -ForegroundColor Cyan

    $out = Join-Path $Dist $rid
    if (Test-Path $out) { Remove-Item $out -Recurse -Force }

    dotnet publish $Project `
        -c Release `
        -r $rid `
        --self-contained true `
        -p:PublishSingleFile=true `
        -p:IncludeNativeLibrariesForSelfExtract=true `
        -o $out

    Write-Host "完成：$out" -ForegroundColor Green
}

if ($Architecture -eq "all") {
    Publish-One "win-x64"
    Publish-One "win-arm64"
}
elseif ($Architecture -eq "x64") {
    Publish-One "win-x64"
}
elseif ($Architecture -eq "arm64") {
    Publish-One "win-arm64"
}
else {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -eq "ARM64") { Publish-One "win-arm64" }
    else { Publish-One "win-x64" }
}
