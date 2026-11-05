# 0001: Derive the hub worker image from the Octopus Tentacle image with the deploy tools baked in

## Status
Accepted (2026-11-03, shipped as `cmnhospitals/octo-tentacle-ubuntu:2026.0`). The base pinning and the hand-built Docker Hub release described below are superseded by [ADR 0002](0002-rebuild-daily-from-the-newest-tentacle-tag.md) (2026-11-04): an ACR task rebuilds from `octopusdeploy/tentacle:latest` every night. The rest stands.

## Context

Moving Octopus steps off the self-hosted BUILDSERVER tentacle splits them across two pools: Octopus-hosted Ubuntu workers for everything that only touches the Azure management plane, and a self-hosted worker inside the Zero Trust hub VNet for the steps that must reach private endpoints (zip deploys to private-only sites, writes to firewalled storage, health checks against private sites, later the database deploys). Octopus-hosted workers have no published egress range, so they can never be allow-listed on a private site's scm endpoint; the hub worker reaches it through the private endpoint and needs no allow list at all.

That worker runs as an Azure Container Instance built from Octopus's `octopusdeploy/tentacle` image, polling Octopus Cloud. A container instance was chosen over a VM because the only VMs planned for the hub (Redgate, Dataedo and two Data Factory integration runtimes) are data servers with their own credentials and reach, and a worker that runs whatever a release's scripts say should not share a machine with them. The container has no OS to patch, is rebuilt from an image tag in Bicep, and was proved on 2026-11-02 against a private-only test site.

The catch is Docker. On a hosted worker, and on a VM, a step runs inside the `octo-deploy-ubuntu` execution container, which is where PowerShell, the Azure CLI, Bicep and AzCopy come from. Container Instances cannot run the privileged Docker-in-Docker daemon the Tentacle image would start (`DISABLE_DIND=Y`), so a step on this worker cannot use an execution container, and the plain Tentacle image carries none of those tools.

## Decision

We will build and publish `cmnhospitals/octo-tentacle-ubuntu`, derived from `octopusdeploy/tentacle` with the same tools and pinned versions as `octo-deploy-ubuntu` installed into the image: PowerShell Core from the GitHub release tarball, Azure CLI from Microsoft's apt feed, Bicep as a pinned binary that `az` is told to use, and AzCopy as a pinned binary. The image adds layers only; the base image's entrypoint, which configures, registers and runs the Tentacle from environment variables, is unchanged.

The base is pinned to an Octopus build-number tag and its digest, not `latest`, so a Tentacle upgrade is a deliberate `FROM` change. The base is Ubuntu 24.04 because that is what Octopus builds the Tentacle on; this image does not follow `octo-deploy-ubuntu` onto 26.04.

Steps that run on this worker's pool carry no `container { }` block in their `.ocl`. The same step on a hosted worker keeps the block and uses `octo-deploy-ubuntu`. The two images pin the same tool versions so a step behaves the same on either pool, and a version bump is made to both together.

The image is built and pushed by hand to Docker Hub, tagged `<year>.<release number that year>` (zero-based), like the other images in this repository.

Alternatives considered:

- A Tentacle plus Docker on a hub VM, keeping the execution-container model everywhere. Rejected: no suitable VM exists in the hub, and a worker must not share a data server.
- The plain `octopusdeploy/tentacle` image, installing tools at the start of each step. Rejected: minutes of downloads on every deployment, and a network dependency in the middle of a deploy.
- Octopus's `worker-tools` image. Rejected: it is an execution container, not a Tentacle, so it does not solve the problem; and the custom image lets us pin exactly what the steps need.

## Consequences

Positive:

- The hub worker runs with no OS to patch; keeping it current is a rebuild from a newer Tentacle tag and a redeploy of the container.
- One tool list and one set of version pins for both pools, so moving a step between pools changes only its pool and container block.
- Registration is handled by the base image's script with `register-worker --force`, so a recreated container takes over its worker record instead of leaving duplicates.

Negative:

- The step shape differs by pool: hub-pool steps must not carry a container block, hosted-pool steps must. That is a per-step rule in every `.ocl` and easy to get wrong; a wrong one fails at run time.
- Any tool a hub-pool step needs beyond these four (Flyway, the Redgate CLIs, `azure.datafactory.tools`) means an image change here first, as it does for `octo-deploy-ubuntu`.
- A Tentacle upgrade is no longer automatic; it is a `FROM` change, a rebuild and a container redeploy. Octopus Cloud tolerates older Tentacles for a long time, but the tag should be refreshed on a cadence.
- Two images now pin the same tool versions; bumping one and not the other makes the pools diverge.
