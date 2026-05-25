param(
    [ValidateSet("all", "windows", "android")]
    [string]$Target = "all",
    [string]$Version = "v1.3.0"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Flutter = "C:\Users\pc\flutter\bin\flutter.bat"
$Inno = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$OutDir = Join-Path $ProjectRoot "out"

Set-Location $ProjectRoot
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if ($Target -eq "all" -or $Target -eq "windows") {
    & $Flutter build windows --release
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $portable = Join-Path $OutDir "comprehensive-exam-system-windows-portable-$Version.zip"
    Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath $portable -Force

    if (Test-Path $Inno) {
        & $Inno "setup_flutter.iss"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } else {
        Write-Warning "Inno Setup not found, skipping Windows installer."
    }
}

if ($Target -eq "all" -or $Target -eq "android") {
    $env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
    & $Flutter build apk --release
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" `
        (Join-Path $OutDir "comprehensive-exam-system-android-$Version.apk") `
        -Force
}

Get-ChildItem $OutDir | Select-Object Name, Length, LastWriteTime
