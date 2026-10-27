# octo-deploy-ubuntu

Ubuntu image used as an Octopus Deploy execution container on Linux workers. It is the Linux counterpart of `octo-deploy-windows` and carries only the tools the Octopus step templates and script modules call: PowerShell Core, Azure CLI, Bicep and AzCopy. See [ADR 0001](doc/adr/0001-trim-octo-deploy-ubuntu-to-the-tools-the-octopus-steps-use.md) for how that list was arrived at and what to do when a step needs something else.

## Base image

`ubuntu:26.04` (Resolute Raccoon, the current LTS), pinned by digest for reproducible builds.

To pick up a newer base, resolve the current digest and update the `FROM` line:

```
docker buildx imagetools inspect ubuntu:26.04
```

Pinning by digest means OS/security patches do **not** flow into this image automatically; the digest needs to be refreshed manually (e.g. on a Patch Tuesday cadence), the same as the Windows image.

## What's installed

| Tool | Build arg | Default | Source |
|---|---|---|---|
| PowerShell Core | `Powershell_Version` | 7.6.4 | GitHub release tarball |
| Azure CLI | `Azure_Cli_Version` | 2.90.0 | packages.microsoft.com apt feed |
| Bicep | `Bicep_Version` | 0.48.1 | GitHub release binary, at `/usr/local/bin/bicep` |
| AzCopy | `Azcopy_Version` | 10.34.1 | GitHub release tarball, at `/usr/local/bin/azcopy` |

Every install step ends with a check that the installed binary reports its pinned version, so a silently wrong package can't produce a "successful" image.

### Notes on how things are installed

- **PowerShell comes from the GitHub release tarball, not apt.** packages.microsoft.com publishes a `powershell` deb for Ubuntu 22.04 and 24.04 but not 26.04. The tarball is Microsoft's documented route for that case and pins the exact version, matching the Windows image's 7.6.4.
- **Azure CLI is 2.90.0, not the Windows image's 2.88.0.** Microsoft's apt feed for Ubuntu 26.04 was opened after 2.88.0 shipped and only carries 2.90.0 and later.
- **Bicep is pre-installed and `az` is told to use it.** Left to itself, `az deployment` downloads Bicep into `~/.azure/bin` on first use, which on an Octopus-hosted worker means on every fresh lease. The image sets `AZURE_BICEP_USE_BINARY_FROM_PATH=true` and `AZURE_BICEP_CHECK_VERSION=false` so `az` uses `/usr/local/bin/bicep` and never looks for an update. The build checks that `az bicep version` reports the pinned version and that no download landed in `/root/.azure/bin`.
- **Octopus execution container requirements.** The image is glibc-based, includes the ICU and other .NET runtime libraries Calamari needs, and defines no `ENTRYPOINT` or `CMD`. Steps run non-interactively, so anything that must be on `PATH` is set in the Dockerfile rather than in a shell profile.

## Building

```
docker build --build-arg Image_Version=2026.1 -t cmnhospitals/octo-deploy-ubuntu:2026.1 .
```

Pass the same value to `Image_Version` and the image tag so the `org.opencontainers.image.version` label always matches the tag it ships under. Tags follow `<year>.<release number that year>`, zero-based (the first push of a year is `.0`).

Requires a Linux container host (Docker Desktop in Linux-containers mode, or a Linux CI runner).

### Checking a build before pushing

```
docker run --rm cmnhospitals/octo-deploy-ubuntu:2026.1 pwsh -NoLogo -Command '$PSVersionTable.PSVersion.ToString()'
docker run --rm cmnhospitals/octo-deploy-ubuntu:2026.1 az version --output tsv --query '"azure-cli"'
docker run --rm cmnhospitals/octo-deploy-ubuntu:2026.1 az bicep version
docker run --rm cmnhospitals/octo-deploy-ubuntu:2026.1 azcopy --version
docker run --rm cmnhospitals/octo-deploy-ubuntu:2026.1 pwsh -NoLogo -Command '(Invoke-RestMethod https://api.github.com).current_user_url'
```

The last one confirms TLS and ICU work inside the container, which is what the Slack, GitHub and health-check steps depend on.
