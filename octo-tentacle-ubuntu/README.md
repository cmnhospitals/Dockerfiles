# octo-tentacle-ubuntu

Octopus Tentacle image with the deploy tools baked in: PowerShell Core, Azure CLI, Bicep and AzCopy, the same list and versions as [`octo-deploy-ubuntu`](../octo-deploy-ubuntu/README.md). It runs as the self-hosted Octopus worker inside the Zero Trust hub VNet, as an Azure Container Instance, polling Octopus Cloud. See [ADR 0001](doc/adr/0001-derive-the-hub-worker-image-from-the-octopus-tentacle-image.md) for why the tools live in the Tentacle image rather than in an execution container.

## Base image

`octopusdeploy/tentacle:<build number>` (Octopus's own Linux Tentacle image, Ubuntu 24.04), pinned to a build-number tag and its digest. Octopus publishes a new tag for every Tentacle build, so a Tentacle upgrade is a `FROM` change here plus a rebuild and retag.

To move to a newer Tentacle:

```
docker buildx imagetools inspect octopusdeploy/tentacle:<tag>
```

and put the tag and the index digest on the `FROM` line.

## What's installed

| Tool | Build arg | Default | Source |
|---|---|---|---|
| PowerShell Core | `Powershell_Version` | 7.6.4 | GitHub release tarball, `/usr/bin/pwsh` |
| Azure CLI | `Azure_Cli_Version` | 2.90.0 | packages.microsoft.com apt feed (noble) |
| Bicep | `Bicep_Version` | 0.48.1 | GitHub release binary, at `/usr/local/bin/bicep` |
| AzCopy | `Azcopy_Version` | 10.34.1 | GitHub release tarball, at `/usr/local/bin/azcopy` |

Every install step ends with a check that the installed binary reports its pinned version. The base image also carries `curl`, `jq`, `openssl`, `sudo` and `xxd`, which Octopus expects on a Tentacle, and a Docker daemon that is never started here (see below).

### How the container runs

- **Entrypoint is the base image's.** `/scripts/configure-and-run.sh` configures the Tentacle from environment variables, registers it, and runs it. This image adds layers only; it changes nothing about startup.
- **Polling, outbound only.** Set `ServerCommsAddress=https://<instance>.octopus.app:10943` and `ServerPort=10943`. Octopus Cloud's polling listener is on 10943; the Tentacle's default of 443 gets a 404.
- **No Docker-in-Docker.** Set `DISABLE_DIND=Y`. Container Instances cannot run the privileged daemon the base image would start, which is the reason the tools are in this image: steps on this worker must not carry a `container { }` block in their `.ocl`. The same step on a hosted worker keeps the block and uses `octo-deploy-ubuntu`.
- **Registration replaces, never duplicates.** The base script registers with `register-worker --force --name <TargetName>`, so a restarted or recreated container takes over the existing worker record of that name in Octopus. No volume is needed for that. Without a volume the Tentacle's certificate is new on every start, which is fine for a polling worker.
- **Registration key.** `ServerApiKey` should belong to a service account whose only permission is registering workers in the target pool. Pass it as a secure environment variable; the entrypoint unsets it before the Tentacle process starts.
- **Bicep never downloads.** `AZURE_BICEP_USE_BINARY_FROM_PATH=true` and `AZURE_BICEP_CHECK_VERSION=false` make `az deployment` use `/usr/local/bin/bicep`.

Variables the base image understands: `ACCEPT_EULA`, `ServerUrl`, `ServerApiKey` (or `BearerToken`), `ServerCommsAddress`, `ServerPort`, `Space`, `TargetWorkerPool`, `TargetName`, `MachinePolicy`, `PollingConnectionCount`, `DISABLE_DIND`.

## Building

```
docker build --build-arg Image_Version=2026.0 -t cmnhospitals/octo-tentacle-ubuntu:2026.0 .
```

Pass the same value to `Image_Version` and the image tag so the `org.opencontainers.image.version` label always matches the tag it ships under. Tags follow `<year>.<release number that year>`, zero-based.

Requires a Linux container host.

### Checking a build before pushing

The base image's entrypoint starts a Tentacle, so override it for the checks:

```
docker run --rm --entrypoint pwsh cmnhospitals/octo-tentacle-ubuntu:2026.0 -NoLogo -Command '$PSVersionTable.PSVersion.ToString()'
docker run --rm --entrypoint az cmnhospitals/octo-tentacle-ubuntu:2026.0 version --output tsv --query '"azure-cli"'
docker run --rm --entrypoint az cmnhospitals/octo-tentacle-ubuntu:2026.0 bicep version
docker run --rm --entrypoint azcopy cmnhospitals/octo-tentacle-ubuntu:2026.0 --version
docker run --rm --entrypoint tentacle cmnhospitals/octo-tentacle-ubuntu:2026.0 version
docker run --rm --entrypoint pwsh cmnhospitals/octo-tentacle-ubuntu:2026.0 -NoLogo -Command '(Invoke-RestMethod https://api.github.com).current_user_url'
```

The real test is a container instance registered as a worker, with a PowerShell step on its pool that calls `az`, `bicep` and `azcopy` and resolves a private endpoint name.
