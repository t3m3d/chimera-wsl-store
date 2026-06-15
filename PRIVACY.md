# Privacy Policy

**App:** Chimera Linux WSL
**Publisher:** t3m3d
**Effective:** 2026-06-15

## Summary

Chimera Linux WSL does not collect, transmit, or share any personal
information. There is no telemetry, no analytics, no third-party SDKs,
no advertising identifiers, and no crash reporting service.

## What the app does

Chimera Linux WSL is a Windows Subsystem for Linux 2 distribution
launcher. When you run it for the first time it:

1. Decompresses a Chimera Linux root filesystem (`install.tar.gz`)
   that is bundled inside the MSIX package on your device.
2. Calls Microsoft's `WslRegisterDistribution` API to register the
   distribution with WSL.
3. Prompts you for a UNIX username and password, which it passes
   directly to the standard Linux `useradd` and `passwd` utilities
   inside the freshly-installed distribution. **These credentials
   never leave your machine.**
4. Drops you into a shell.

On subsequent launches it just runs `wsl --launch` for the registered
distribution.

## Network activity

The launcher itself does not initiate any network connections.

The bundled Chimera Linux distribution includes the `apk-tools`
package manager. When you choose to install or update packages with
`apk`, the package manager connects to Chimera Linux's official
repository at `https://repo.chimera-linux.org`. This is the same
behavior you would get installing Chimera Linux from its official
website. We do not log, intercept, or proxy these connections.

## Data on disk

Everything that lives on disk lives on **your** disk:

- The Chimera Linux root filesystem extracted to your WSL VHDX file
- The username, password hash, and shell history of the Linux user
  you create
- Any files you create or download inside the WSL distribution

We have no access to any of this.

## Microsoft Store

If you obtain the app through the Microsoft Store, Microsoft
collects and processes data per its own
[Privacy Statement](https://privacy.microsoft.com/privacystatement).
That data flow is between you and Microsoft; we receive only the
aggregate sales statistics that Microsoft surfaces to publishers.

## Children

The app is not directed at children under 13 and we do not knowingly
collect data from anyone — see the Summary above.

## Changes

We will update this policy if anything material changes (e.g. if a
future version of the app ever adds telemetry, which is not planned).
The "Effective" date at the top reflects the most recent revision.

## Contact

Privacy questions, takedown requests, or anything else:
**brian@krypton-lang.org**

The launcher source is open at
<https://github.com/t3m3d/chimera-wsl-store> if you want to verify
any of the above.
