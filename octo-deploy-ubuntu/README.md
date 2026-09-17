# octo-deploy-ubuntu

Ubuntu image used as an Octopus Deploy worker. It is the Linux counterpart of `octo-deploy-windows` and carries the same core toolset (Azure CLI, PowerShell Core, Python, 7-Zip) plus Linux-only extras (Octopus CLI, `Octopus.Client`, the `Az` and `azure.datafactory.tools` PowerShell modules, the .NET SDK, and Node.js).

## Base image

`ubuntu:26.04` (Resolute Raccoon, the current LTS), pinned by digest for reproducible builds.

To pick up a newer base, resolve the current digest and update the `FROM` line:

```
docker buildx imagetools inspect ubuntu:26.04
```

Pinning by digest means OS/security patches do **not** flow into this image automatically; the digest needs to be refreshed manually (e.g. on a Patch Tuesday cadence), the same as the Windows image.

## What's installed

Tools shared with `octo-deploy-windows`:

| Tool | Build arg | Default | Source |
|---|---|---|---|
| Azure CLI | `Azure_Cli_Version` | 2.90.0 | packages.microsoft.com apt feed |
| PowerShell Core | `Powershell_Version` | 7.6.4 | GitHub release tarball |
| Python 3 (with pip and venv) | (Ubuntu archive) | 3.14 | Ubuntu archive |
| 7-Zip | `SevenZip_Version` | 26.02 | 7-zip.org Linux build |

Ubuntu-only tools:

| Tool | Build arg | Default | Source |
|---|---|---|---|
| Octopus CLI | `Octopus_Cli_Version` | 9.0.0 | apt.octopus.com |
| Octopus.Client | `Octopus_Client_Version` | 17.1.2309 | nuget.org (assemblies copied to `/`) |
| Az PowerShell module | `Azure_Powershell_Version` | 14.3.0 | PowerShell Gallery |
| azure.datafactory.tools | `Azure_DataFactory_Tools_Version` | 1.13.0 | PowerShell Gallery |
| .NET SDK | `Dotnet_Sdk_Version` | 10.0 | Ubuntu archive (Canonical build) |
| Node.js | `Node_Major_Version` | 22 | NodeSource |

Every install step that has a pinned version ends with a check that the installed binary reports that version, so a silently wrong package can't produce a "successful" image.

### Where the Ubuntu image differs from the Windows image, and why

- **Azure CLI is 2.90.0, not 2.88.0.** Microsoft's apt feed for Ubuntu 26.04 was opened after 2.88.0 shipped and only carries 2.90.0 and later. The Windows image could be bumped to match when Chocolatey publishes 2.90.0.
- **PowerShell comes from the GitHub release tarball, not apt.** packages.microsoft.com publishes a `powershell` deb for Ubuntu 22.04 and 24.04 but not 26.04. The tarball is Microsoft's documented route for that case and pins the exact version, matching the Windows image's 7.6.4.
- **The 7-Zip build arg is `SevenZip_Version`, not `7Zip_Version`.** Shell variable names can't start with a digit. The version value is the same. The upstream Linux binary is `7zz`; a `7z` symlink is added so scripts written for Windows `7z.exe` or p7zip work unchanged.
- **Python is the Ubuntu-packaged 3.14, not a pinned 3.13.x.** The Ubuntu archive is the supported route on Linux and receives security updates with the OS. `python` and `pip` are symlinked to `python3` and `pip3`. Ubuntu marks its Python as "externally managed" (PEP 668) and refuses plain `pip install`; the image sets `PIP_BREAK_SYSTEM_PACKAGES=1` so `pip install` behaves the way it does on the Windows image. Use `python -m venv` if you need isolation.
- **.NET SDK is 10.0, not 8.0.** Neither Canonical nor packages.microsoft.com package .NET 8 for Ubuntu 26.04. .NET 8 reaches end of support in November 2026 regardless.
- **Node.js is 22.x, not 20.x.** Node 20 reached end of life in April 2026.

## Building

```
docker build --build-arg Image_Version=1.2.3 -t <registry>/octo-deploy-ubuntu:1.2.3 .
```

Pass the same value to `Image_Version` and the image tag so the `org.opencontainers.image.version` label always matches the tag it ships under.

Requires a Linux container host (Docker Desktop in Linux-containers mode, or a Linux CI runner).
