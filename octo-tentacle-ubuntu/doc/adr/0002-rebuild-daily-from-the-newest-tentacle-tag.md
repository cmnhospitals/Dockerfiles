# 0002: Rebuild nightly with an ACR task from the newest Tentacle image

## Status
Accepted (2026-11-04)

## Context

ADR 0001 pins the base image to one `octopusdeploy/tentacle` build and has the image built and pushed by hand. Octopus publishes a new Tentacle build most working days and points `latest` at it, and the hub worker should stay on the newest one without anyone remembering to rebuild.

The worker already pulls its image from an Azure Container Registry with a managed identity, because Container Instances cannot pull from Docker Hub anonymously. A container group never checks its registry for a newer image on its own, but `az container restart` re-pulls the tag if it has moved.

## Decision

The Dockerfile builds `FROM octopusdeploy/tentacle:latest`, and an ACR task in the worker's registry, defined by `acr-task.yaml`, owns the image's lifecycle:

1. **A timer runs it every night at 07:00 UTC** (midnight MST; 1:00 local while Denver is on MDT, since ACR schedules are UTC only). It pulls `octopusdeploy/tentacle:latest` fresh each time. That is a verified-publisher image, so Docker Hub's anonymous pull limit does not apply. The base image trigger is off.
2. **The task builds from this repository and pushes into the registry** as `octo-tentacle-ubuntu:latest` and `octo-tentacle-ubuntu:<run id>`. The Dockerfile's install steps assert each tool's pinned version, so a bad build fails before anything is pushed.
3. **The task restarts the worker's container group**, which pulls the new `latest`. The container group's definition never changes.

Rolling back is pointing the container group at an earlier `<run id>` tag. The worker's Octopus machine policy keeps Tentacle updates at "never": the image is the only way the Tentacle changes.

The image is no longer pushed to Docker Hub; nothing pulls it from there. This directory is not in Dependabot's updates, since there is nothing pinned for it to bump.

Alternatives considered:

- A GitHub Actions workflow that builds, pushes to Docker Hub, imports into ACR and runs an Octopus runbook to roll the worker. Rejected: four systems and their secrets to do what one ACR task does.
- ACR's base image trigger, which runs the task within 10 to 60 minutes of Octopus publishing. Chosen first, then rejected: the restart lands at any time of day, and a deployment step running on the worker at that moment fails. A nightly restart costs nothing, since nothing deploys at midnight.

## Consequences

- The worker is at most one day behind the newest Tentacle.
- The worker restarts every night for about a minute, whether or not Octopus published anything new. A deployment step running on it then fails and needs a retry; at midnight that is rare.
- The task's managed identity needs rights to restart the container group (pushing to its own registry needs none). This repository is public, so the task reads it without a token.
- A tool version change is an edit to the Dockerfile's `ARG`, made together with the matching change in `octo-deploy-ubuntu`; it takes effect on the next nightly run, or immediately with a manual `az acr task run`.
