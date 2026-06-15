[CmdletBinding()]
param(
    [string]$Subject = 'CN=t3m3d',
    [string]$OutPath,
    [SecureString]$Password
)

$ErrorActionPreference = 'Stop'

if ($PSScriptRoot) { $ScriptRoot = $PSScriptRoot }
else               { $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $OutPath) { $OutPath = Join-Path $ScriptRoot 'devcert.pfx' }
if (-not $Password) { $Password = ConvertTo-SecureString -String 'chimera-dev' -AsPlainText -Force }

Write-Host "[make-cert] generating self-signed code-signing cert for $Subject" -ForegroundColor Cyan
$cert = New-SelfSignedCertificate `
    -Type Custom `
    -Subject $Subject `
    -KeyUsage DigitalSignature `
    -FriendlyName "Chimera WSL dev cert" `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
Write-Host "[OK] thumbprint: $($cert.Thumbprint)" -ForegroundColor Green

Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $OutPath -Password $Password | Out-Null
Write-Host "[OK] exported to $OutPath" -ForegroundColor Green

Write-Host ""
Write-Host "To trust this cert (so sideloaded MSIX installs), run as ADMIN:" -ForegroundColor Yellow
Write-Host "  Import-PfxCertificate -FilePath '$OutPath' -CertStoreLocation Cert:\LocalMachine\TrustedPeople -Password (ConvertTo-SecureString 'chimera-dev' -AsPlainText -Force)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Then sign the MSIX:" -ForegroundColor Yellow
Write-Host "  .\build-msix.ps1 -Sign" -ForegroundColor Yellow
Write-Host ""
Write-Host "Then install:" -ForegroundColor Yellow
Write-Host "  Add-AppxPackage .\AppPackages\Chimera.msix" -ForegroundColor Yellow
