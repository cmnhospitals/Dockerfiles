# octo-deploy-windows

Windows Server Core image used as an Octopus Deploy worker, with Azure CLI, PowerShell Core, Python, and 7-Zip preinstalled. Azure CLI, PowerShell Core, and 7-Zip are installed via Chocolatey; Python is installed from python.org's embeddable zip distribution with pip bootstrapped manually (see below).

## Base image

`mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019`, pinned by digest for reproducible builds. This is Microsoft's own `ltsc2019` servercore image with .NET Framework 4.8 preinstalled.

Chocolatey CLI 2.x requires .NET Framework 4.8, but plain `windows/servercore:ltsc2019` only ships 4.7.2. Installing 4.8 inside a `RUN` step works, but it's slow (a single-threaded Framework in-place upgrade) and leaves an unresolved "reboot required" warning, since a Docker layer commit isn't the same as an actual OS restart. Starting from an image that already has 4.8 baked in avoids both problems.

To pick up a newer patch, resolve the current digest and update the `FROM` line:

```
docker buildx imagetools inspect mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019
```

Pinning by digest means OS/security patches do **not** flow into this image automatically, the digest needs to be refreshed manually (e.g. on a Patch Tuesday cadence).

## What's installed

| Tool | Build arg | Default |
|---|---|---|
| Chocolatey | `Chocolatey_Version` | 2.7.3 |
| Azure CLI | `Azure_Cli_Version` | 2.88.0 |
| Python 3 | `Python_Version` | 3.13.8 |
| 7-Zip | `7Zip_Version` | 26.2.0 |
| PowerShell Core | `Powershell_Version` | 7.6.4 |

Each `choco install` checks `$LASTEXITCODE` and fails the build (throws) on any exit code other than `0` or `3010` (reboot required, still a success), so a broken install can't silently produce a "successful" image.

### Why Python is installed from a zip instead of an installer

Chocolatey's `python3` package pulls in `vcredist140`/`vcredist2015` as automatic dependencies. In practice, `vcredist140`'s x64 install (a WiX Burn-bootstrapper `.exe`, not a plain `.msi`) deadlocked, the process stayed alive but sat at ~0% CPU indefinitely, eventually hitting Chocolatey's 45-minute execution timeout and cascading to fail `vcredist2015`, `python313`, and `python3` all at once.

Switching to python.org's own full installer (`python-*-amd64.exe`) hit the identical deadlock, it's built with the same Burn bootstrapper technology. Plain `.msi` installs (e.g. Azure CLI's, a step earlier in this same Dockerfile) work fine in this environment, the problem is specifically Burn-wrapped bootstrapper `.exe`s.

The fix: install Python from the official **embeddable zip distribution** instead, just files, no installer/bootstrapper to hang. Since the embeddable distribution ships without `pip`, `pip` is bootstrapped afterward via `get-pip.py`, and `import site` is uncommented in the generated `python313._pth` file (required for `site-packages`/`pip` to work at all in the embeddable distribution).

Caveat: like the installer route, this doesn't bring in `msvcp140.dll` (the C++ runtime, distinct from `vcruntime140.dll`). If a future `pip`-installed package needs it for a C++ extension module, `vcredist140` would need to be installed as a follow-up step, and would need the same Burn-hang workaround if attempted via Chocolatey.

## Building

```
docker build --build-arg Image_Version=1.2.3 -t <registry>/octo-deploy-windows:1.2.3 .
```

Pass the same value to `Image_Version` and the image tag so the `org.opencontainers.image.version` label always matches the tag it ships under. `Image_Version` defaults to `1.0.0` for ad-hoc local builds where no build arg is supplied.

Requires a Windows container host (Docker Desktop in Windows-containers mode, or a Windows CI runner), this will not build against a Linux Docker daemon.

## Known gaps

This image does not install Octopus CLI, `Octopus.Client`, or the `Az` PowerShell module, unlike its `octo-deploy-ubuntu` counterpart. Confirm whether that tooling is supplied another way for Windows workers before relying on this image for release/deploy steps that need it.
