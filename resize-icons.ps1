[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'

if ($PSScriptRoot) { $ScriptRoot = $PSScriptRoot }
else               { $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $OutDir) { $OutDir = Join-Path $ScriptRoot 'DistroLauncher-Appx\Assets' }

if (-not (Test-Path $Source)) { throw "missing source: $Source" }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

Add-Type -AssemblyName System.Drawing

$ASSETS = @(
    @{ Name = 'StoreLogo';           W = 50;  H = 50  }
    @{ Name = 'Square44x44Logo';     W = 44;  H = 44  }
    @{ Name = 'Square71x71Logo';     W = 71;  H = 71  }
    @{ Name = 'Square150x150Logo';   W = 150; H = 150 }
    @{ Name = 'LargeTile';           W = 310; H = 310 }
    @{ Name = 'SmallTile';           W = 71;  H = 71  }
    @{ Name = 'Wide310x150Logo';     W = 310; H = 150 }
    @{ Name = 'SplashScreen';        W = 620; H = 300 }
)
$SCALES = @(100, 125, 150, 200, 400)

$src = [System.Drawing.Image]::FromFile((Resolve-Path $Source).Path)
Write-Host "[resize-icons] source: $($src.Width)x$($src.Height)  -> $OutDir" -ForegroundColor Cyan

function Resize-Png([System.Drawing.Image]$src, [int]$w, [int]$h, [string]$outPath) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality= [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    # Fit square source into wide targets by center-cropping the source aspect.
    $srcW = $src.Width; $srcH = $src.Height
    $targetRatio = $w / $h
    $srcRatio    = $srcW / $srcH
    if ($srcRatio -gt $targetRatio) {
        $cropW = [int]($srcH * $targetRatio); $cropH = $srcH
        $cropX = [int](($srcW - $cropW) / 2); $cropY = 0
    } else {
        $cropW = $srcW; $cropH = [int]($srcW / $targetRatio)
        $cropX = 0;     $cropY = [int](($srcH - $cropH) / 2)
    }
    $srcRect = New-Object System.Drawing.Rectangle $cropX, $cropY, $cropW, $cropH
    $dstRect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $g.DrawImage($src, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

$count = 0
foreach ($asset in $ASSETS) {
    $base = $asset.Name
    foreach ($scale in $SCALES) {
        $w = [int][math]::Round($asset.W * $scale / 100)
        $h = [int][math]::Round($asset.H * $scale / 100)
        $out = Join-Path $OutDir ("{0}.scale-{1}.png" -f $base, $scale)
        Resize-Png $src $w $h $out
        $count++
    }
    # Also write the unscaled base name (MakeAppx-without-MakePri needs these)
    $out = Join-Path $OutDir ("{0}.png" -f $base)
    Resize-Png $src $asset.W $asset.H $out
    $count++
}
$src.Dispose()
Write-Host "[OK] wrote $count files to $OutDir" -ForegroundColor Green
