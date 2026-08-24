param(
    [ValidateSet("auto", "x64", "arm64", "all")]
    [string]$Architecture = "auto"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Project = Join-Path $Root "SafeMacCleaner.Windows.csproj"
$Dist = Join-Path $Root "dist"
$ExpectedExeName = "SafeMacCleanerLite.exe"

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

    & dotnet publish $Project `
        -c Release `
        -r $rid `
        --self-contained true `
        -p:PublishSingleFile=true `
        -p:IncludeNativeLibrariesForSelfExtract=true `
        -o $out

    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish $rid 失败，退出码：$LASTEXITCODE"
    }

    if (-not (Test-Path $out)) {
        throw "构建输出目录不存在：$out"
    }

    $expectedExe = Join-Path $out $ExpectedExeName
    if (-not (Test-Path $expectedExe)) {
        $publishedExe = Get-ChildItem -Path $out -Filter *.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $publishedExe) {
            throw "构建完成但未找到可执行文件：$out"
        }
        Write-Host "提示：实际生成的可执行文件为 $($publishedExe.Name)" -ForegroundColor Yellow
    }

    Write-Host "完成：$out" -ForegroundColor Green
}

try {
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
}
catch {
    Write-Host ""
    Write-Host "Windows 构建失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

exit 0
