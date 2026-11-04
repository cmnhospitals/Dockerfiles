# 0002: Rebuild with an ACR task whenever the Tentacle base image moves

## Status
Accepted (2026-11-04)

## Context

ADR 0001 pins the base image to one `octopusdeploy/tentacle` build and has the image built and pushed by hand. Octopus publishes a new Tentacle build most working days and points `latest` at it, and the hub worker should stay on the newest one without anyone remembering to rebuild.

The worker already pulls its image from an Azure Container Registry with a managed identity, because Container Instances cannot pull from Docker Hub anonymously. A container group never checks its registry for a newer image on its own, but `az container restart` re-pulls the tag if it has moved.

## Decision

The Dockerfile builds `FROM octopusdeploy/tentacle:latest`, and an ACR task in the worker's registry, defined by `acr-task.yaml`, owns the image's lifecycle:

1. **ACR's base image tracking triggers it.** `octopusdeploy/tentacle` is a public Docker Hub repo with a stable tag, so ACR checks it every 10 to 60 minutes and runs the task when it moves. It is a verified-publisher image, so Docker Hub's anonymous pull limit does not apply.
2. **The task builds from this repository and pushes into the registry** as `octo-tentacle-ubuntu:latest` and `octo-tentacle-ubuntu:<run id>`. The Dockerfile's install steps assert each tool's pinned version, so a bad build fails before anything is pushed.
3. **The task restarts the worker's container group**, which pulls the new `latest`. The container group's definition never changes.

Rolling back is pointing the container group at an earlier `<run id>` tag. The worker's Octopus machine policy keeps Tentacle updates at "never": the image is the only way the Tentacle changes.

The image is no longer pushed to Docker Hub; nothing pulls it from there. This directory is not in Dependabot's updates, since there is nothing pinned for it to bump.

Alternatives considered:

- A GitHub Actions workflow that builds, pushes to Docker Hub, imports into ACR and runs an Octopus runbook to roll the worker. Rejected: four systems and their secrets to do what one ACR task does.
- A daily timer instead of the base image trigger, to keep restarts out of the working day. Rejected: it restarts the worker every day whether or not anything changed.

## Consequences

- The worker is on the newest Tentacle within about an hour of Octopus publishing it.
- The restart takes about a minute and can come at any time of day. A deployment step running on the worker at that moment fails and needs a retry.
- The task's managed identity needs push rights on the registry and rights to restart the container group, and the task needs a GitHub token to read this private repository.
- A tool version change is an edit to the Dockerfile's `ARG`, made together with the matching change in `octo-deploy-ubuntu`; it takes effect on the next base image update, or on a manual `az acr task run`.
