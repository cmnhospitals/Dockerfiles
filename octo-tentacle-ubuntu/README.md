# octo-tentacle-ubuntu

Octopus Tentacle image with the deploy tools baked in: PowerShell Core, Azure CLI, Bicep and AzCopy, the same list and versions as [`octo-deploy-ubuntu`](../octo-deploy-ubuntu/README.md). It runs as the self-hosted Octopus worker inside the Zero Trust hub VNet, as an Azure Container Instance, polling Octopus Cloud. See [ADR 0001](doc/adr/0001-derive-the-hub-worker-image-from-the-octopus-tentacle-image.md) for why the tools live in the Tentacle image rather than in an execution container.

## Base image and lifecycle

`octopusdeploy/tentacle:latest` (Octopus's own Linux Tentacle image, Ubuntu 24.04). Octopus publishes a build most days and `latest` follows it. An ACR task in the worker's registry, defined by [`acr-task.yaml`](acr-task.yaml), rebuilds this image whenever `latest` moves, pushes it as `octo-tentacle-ubuntu:latest` and `octo-tentacle-ubuntu:<run id>`, and restarts the worker's container group so it pulls the new image. See [ADR 0002](doc/adr/0002-rebuild-daily-from-the-newest-tentacle-tag.md).

Creating the task (system-assigned identity; it needs rights to restart the container group and none to push to its own registry; this repository is public, so no token):

```
az acr task create --registry <acr> --name octo-tentacle-ubuntu \
  --context https://github.com/cmnhospitals/Dockerfiles.git#main:octo-tentacle-ubuntu \
  --file acr-task.yaml --commit-trigger-enabled false \
  --assign-identity [system] \
  --set WorkerResourceGroup=<rg> --set WorkerName=<container group>
az acr task run --registry <acr> --name octo-tentacle-ubuntu
```

The first run is required: ACR only starts tracking the base image after the task has built once.

**Rolling back.** Point the container group at an earlier `octo-tentacle-ubuntu:<run id>` tag.

**Changing a tool version.** Edit the `ARG` in the Dockerfile, in the same change as the matching edit in `octo-deploy-ubuntu` so both pools stay on the same versions, then `az acr task run` to pick it up without waiting for the next Tentacle build.

**Octopus side.** The worker's machine policy must leave Tentacle updates at "never" (the Default Machine Policy does): the image is the only way the Tentacle changes.

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
- **Registration replaces, never duplicates.** The base script registers with `register-worker --force --name <TargetName>`, so a restarted container takes over the existing worker record of that name in Octopus. No volume is needed.
- **Registration key.** `ServerApiKey` should belong to a service account whose only permission is registering workers in the target pool. Pass it as a secure environment variable; the entrypoint unsets it before the Tentacle process starts.
- **Bicep never downloads.** `AZURE_BICEP_USE_BINARY_FROM_PATH=true` and `AZURE_BICEP_CHECK_VERSION=false` make `az deployment` use `/usr/local/bin/bicep`.

Variables the base image understands: `ACCEPT_EULA`, `ServerUrl`, `ServerApiKey` (or `BearerToken`), `ServerCommsAddress`, `ServerPort`, `Space`, `TargetWorkerPool`, `TargetName`, `MachinePolicy`, `PollingConnectionCount`, `DISABLE_DIND`.

## Building by hand

To try a change before it reaches `main`:

```
docker build --pull -t octo-tentacle-ubuntu:dev .
```

Requires a Linux container host. The base image's entrypoint starts a Tentacle, so override it to poke around: `docker run --rm -it --entrypoint pwsh octo-tentacle-ubuntu:dev`.
