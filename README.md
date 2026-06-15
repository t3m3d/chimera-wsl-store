# chimera-wsl-store

Microsoft Store MSIX package for [Chimera Linux](https://chimera-linux.org/) on WSL2.

Built on top of Microsoft's official
[WSL-DistroLauncher](https://github.com/microsoft/WSL-DistroLauncher) C++
template — customized for Chimera (musl + LLVM + dinit + apk-tools + FreeBSD userland).

Sibling repo: [chimera-wsl2-installer](https://github.com/t3m3d/chimera-wsl2-installer) —
PowerShell installer for users who don't want a Store account.

## What this builds

A single `.msixbundle` you can:

- **sideload locally** — `Add-AppxPackage Chimera.msixbundle` (needs Developer
  Mode + the dev cert trusted)
- **submit to Microsoft Store** — upload via [Partner Center](https://partner.microsoft.com/dashboard)

After install, `chimera.exe` is on PATH and `wsl --list` shows `Chimera`.

## Build

You need:

- **Visual Studio 2022** with the "Desktop development with C++" workload, OR
- **Visual Studio Build Tools 2022** + Windows SDK 10.0.16299.0 or later
- **PowerShell 5.1+**

### Steps

```powershell
# 1. Fetch the Chimera rootfs (~115 MB, sha-verified against upstream)
.\fetch-rootfs.ps1

# 2. Open the solution in VS and Build > Build Solution (Release|x64)
#    OR from the command line:
msbuild DistroLauncher.sln /p:Configuration=Release /p:Platform=x64 /p:AppxBundle=Always /p:AppxBundlePlatforms=x64
```

The resulting `.msixbundle` lands in `AppPackages\DistroLauncher-Appx_*_Test\`.

### Sideload test

```powershell
# Trust the test cert (one-time, admin)
$cert = (Get-AuthenticodeSignature .\AppPackages\...\*.msixbundle).SignerCertificate
Import-Certificate -CertStoreLocation Cert:\LocalMachine\TrustedPeople -FilePath cert.cer

# Install
Add-AppxPackage .\AppPackages\...\*.msixbundle

# Run
chimera.exe
```

First launch:
1. Decompresses `install.tar.gz`, calls `WslRegisterDistribution`
2. Prompts for a UNIX username + password (OOBE)
3. Drops you into a bash shell

Subsequent launches go straight to the shell.

## Layout

```
chimera-wsl-store/
├── DistroLauncher/             C++ launcher source (MS template, Chimera-customized)
│   ├── DistributionInfo.h      Name = "Chimera", WindowTitle
│   ├── DistributionInfo.cpp    OOBE: useradd in wheel group + doas + chpasswd
│   └── ...                     (WslApiLoader, Helpers, etc.)
├── DistroLauncher-Appx/
│   ├── MyDistro.appxmanifest   Identity, Publisher, DisplayName, ExecutionAlias
│   ├── Assets/                 Icons (replace these to taste)
│   └── ...
├── x64/install.tar.gz          ← fetched by fetch-rootfs.ps1 (gitignored, 115 MB)
├── DistroLauncher.sln
├── fetch-rootfs.ps1            Pulls latest sha-verified rootfs
└── README.md                   (you are here)
```

## Customization done

| File | What changed |
|---|---|
| `DistributionInfo.h` | `Name = L"Chimera"`, `WindowTitle = L"Chimera Linux"` |
| `DistributionInfo.cpp` | OOBE uses `useradd -G wheel` + `doas` (Chimera's sudo replacement) |
| `MyDistro.appxmanifest` | Identity `t3m3d.ChimeraLinuxWSL`, Publisher `CN=t3m3d`, alias `chimera.exe` |
| `DistroLauncher.vcxproj` | `TargetName=chimera` (output exe name) |
| `DistroLauncher-Appx.vcxproj` | `TargetName=chimera` |
| `Assets/` | (default MS icons — swap for Chimera artwork before Store submission) |

## License

MIT. Launcher template © Microsoft; see `LICENSE`.
