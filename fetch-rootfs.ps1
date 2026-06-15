[CmdletBinding()]
param(
    [string]$RootfsBase = 'https://repo.chimera-linux.org/live/latest',
    [string]$OutDir = (Join-Path $PSScriptRoot 'x64')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Chimera's sha256sums.txt lines look like:
#   <64-hex>  chimera-linux-x86_64-ROOTFS-20251220-full.tar.gz
# If upstream ever changes that format, this regex is what to edit.
$needle = '^([0-9a-f]{64})\s+chimera-linux-x86_64-ROOTFS-(\d+)-full\.tar\.gz$'

Write-Host "[fetch] reading $RootfsBase/sha256sums.txt"
$sums = (Invoke-WebRequest -Uri "$RootfsBase/sha256sums.txt" -UseBasicParsing -TimeoutSec 30).Content
$match = $null
foreach ($line in ($sums -split "`r?`n")) {
    if ($line -match $needle) { $match = $matches; break }
}
if (-not $match) { throw "couldn't find chimera-linux-x86_64-ROOTFS-*-full.tar.gz in sha256sums.txt" }

$expectedSha = $match[1]
$stageDate   = $match[2]
$stageFile   = "chimera-linux-x86_64-ROOTFS-$stageDate-full.tar.gz"
$stageUrl    = "$RootfsBase/$stageFile"
$outPath     = Join-Path $OutDir 'install.tar.gz'

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

function Get-Sha256Hex([string]$path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $fs = [System.IO.File]::OpenRead($path)
        try { $bytes = $sha.ComputeHash($fs) } finally { $fs.Dispose() }
    } finally { $sha.Dispose() }
    return ([System.BitConverter]::ToString($bytes) -replace '-','').ToLower()
}

if (Test-Path $outPath) {
    $h = Get-Sha256Hex $outPath
    if ($h -eq $expectedSha.ToLower()) {
        Write-Host "[fetch] cached install.tar.gz matches upstream ($stageFile) -- skipping" -ForegroundColor Green
        exit 0
    }
}

Write-Host "[fetch] downloading $stageFile (~115 MB)"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-WebRequest -Uri $stageUrl -OutFile $outPath -UseBasicParsing
$sw.Stop()
$actual = Get-Sha256Hex $outPath
if ($actual -ne $expectedSha.ToLower()) {
    throw "SHA256 mismatch. Expected $expectedSha, got $actual"
}
$mb = [math]::Round((Get-Item $outPath).Length / 1MB, 1)
Write-Host "[fetch] OK: $stageFile ($mb MB in $([math]::Round($sw.Elapsed.TotalSeconds,1))s, sha verified)" -ForegroundColor Green
