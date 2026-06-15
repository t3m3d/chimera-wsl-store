[CmdletBinding()]
param(
    [string]$Configuration = 'Release',
    [string]$Platform = 'x64',
    [switch]$Sign,
    [string]$CertPath,
    [SecureString]$CertPassword
)

$ErrorActionPreference = 'Stop'

if ($PSScriptRoot) { $ScriptRoot = $PSScriptRoot }
else               { $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $ScriptRoot) { $ScriptRoot = (Get-Location).Path }
if (-not $CertPath) { $CertPath = Join-Path $ScriptRoot 'devcert.pfx' }

function Say([string]$m) { Write-Host "[build-msix] $m" -ForegroundColor Cyan }
function OK ([string]$m) { Write-Host "[OK] $m"         -ForegroundColor Green }
function Fail([string]$m) { Write-Host "[FAIL] $m"      -ForegroundColor Red; exit 1 }

# Locate MakeAppx + signtool from the latest installed Windows SDK.
$sdkBinRoot = 'C:\Program Files (x86)\Windows Kits\10\bin'
$sdkVer = (Get-ChildItem $sdkBinRoot -Directory -Filter '10.*' |
           Sort-Object Name -Descending | Select-Object -First 1).Name
if (-not $sdkVer) { Fail "no Windows 10 SDK found under $sdkBinRoot" }
$sdkBin = Join-Path $sdkBinRoot "$sdkVer\x64"
$makeAppx = Join-Path $sdkBin 'makeappx.exe'
$signTool = Join-Path $sdkBin 'signtool.exe'
foreach ($t in $makeAppx, $signTool) {
    if (-not (Test-Path $t)) { Fail "missing tool: $t" }
}
OK "SDK $sdkVer (makeappx + signtool)"

# 1. Build the launcher exe (just the C++ project, skip the broken Appx project).
Say "msbuild launcher ($Configuration|$Platform)"
$launcherProj = Join-Path $ScriptRoot 'DistroLauncher\DistroLauncher.vcxproj'
& msbuild $launcherProj /p:Configuration=$Configuration /p:Platform=$Platform /v:minimal /nologo
if ($LASTEXITCODE -ne 0) { Fail "msbuild failed (rc=$LASTEXITCODE)" }
$launcherExe = Join-Path $ScriptRoot "$Platform\$Configuration\chimera.exe"
if (-not (Test-Path $launcherExe)) { Fail "expected chimera.exe at $launcherExe" }
OK "built $launcherExe"

# 2. Verify the rootfs tarball is staged.
$tarball = Join-Path $ScriptRoot "$Platform\install.tar.gz"
if (-not (Test-Path $tarball)) { Fail "missing $tarball -- run .\fetch-rootfs.ps1 first" }
OK "rootfs: $tarball"

# 3. Assemble layout dir for MakeAppx.
$layout = Join-Path $ScriptRoot 'msix-layout'
if (Test-Path $layout) { Remove-Item -Recurse -Force $layout }
New-Item -ItemType Directory -Path $layout | Out-Null
Copy-Item $launcherExe (Join-Path $layout 'chimera.exe')
Copy-Item $tarball (Join-Path $layout 'install.tar.gz')
# Auto-bump the manifest Version's build number to the current minute since
# 2024-01-01 so each rebuild produces a strictly higher version. Without
# this, Add-AppxPackage silently no-ops on re-install of the same version.
$mfPath = Join-Path $ScriptRoot 'DistroLauncher-Appx\MyDistro.appxmanifest'
$mfXml  = Get-Content $mfPath -Raw
$build  = [int]([DateTime]::UtcNow - [DateTime]'2024-01-01Z').TotalMinutes
$mfXml  = $mfXml -replace 'Version="\d+\.\d+\.\d+\.\d+"', "Version=`"1.0.$build.0`""
$layoutManifest = Join-Path $layout 'AppxManifest.xml'
Set-Content -Path $layoutManifest -Value $mfXml -Encoding UTF8 -NoNewline
Say "manifest version 1.0.$build.0"
Copy-Item -Recurse (Join-Path $ScriptRoot 'DistroLauncher-Appx\Assets') $layout

# MakeAppx (without resources.pri / MakePri) wants the base-name files the
# manifest references. The template ships only scale-100/125/150/200/400
# variants. Copy each scale-100 to the unscaled base name so manifest
# refs like 'Assets\StoreLogo.png' resolve.
$assetsDir = Join-Path $layout 'Assets'
Get-ChildItem $assetsDir -Filter '*.scale-100.png' | ForEach-Object {
    $base = $_.Name -replace '\.scale-100\.png$','.png'
    Copy-Item -Force $_.FullName (Join-Path $assetsDir $base)
}
OK "layout: $layout"

# 4. Pack the MSIX.
$outDir = Join-Path $ScriptRoot 'AppPackages'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$msix = Join-Path $outDir 'Chimera.msix'
if (Test-Path $msix) { Remove-Item -Force $msix }
Say "makeappx pack -> $msix"
& $makeAppx pack /d $layout /p $msix /o
if ($LASTEXITCODE -ne 0) { Fail "makeappx failed (rc=$LASTEXITCODE)" }
$mb = [math]::Round((Get-Item $msix).Length / 1MB, 1)
OK "packed: $msix ($mb MB)"

# 5. Optional signing.
if ($Sign) {
    if (-not (Test-Path $CertPath)) { Fail "missing $CertPath -- run .\make-cert.ps1 first" }
    if ($CertPassword) {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertPassword)
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    } else {
        $plain = 'chimera-dev'
    }
    Say "signtool sign /v with $CertPath"
    & $signTool sign /fd SHA256 /v /f $CertPath /p $plain $msix
    if ($LASTEXITCODE -ne 0) { Fail "signtool failed (rc=$LASTEXITCODE)" }
    OK "signed"
} else {
    Write-Host "[note] MSIX is unsigned. To sideload-test, sign with:" -ForegroundColor Yellow
    Write-Host "       .\build-msix.ps1 -Sign" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Built $msix"                                -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
