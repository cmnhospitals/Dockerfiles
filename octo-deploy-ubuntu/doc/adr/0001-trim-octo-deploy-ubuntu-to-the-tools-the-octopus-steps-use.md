# 0001: Trim octo-deploy-ubuntu to the tools the Octopus steps use

## Status
Accepted (2026-10-26, shipped as `cmnhospitals/octo-deploy-ubuntu:2026.1`)

## Context

`octo-deploy-ubuntu` is the Linux execution container for Octopus Deploy worker steps, the counterpart of `octo-deploy-windows`. It was created as a first attempt at rebuilding the Windows image for Linux, ahead of moving every Octopus step off the self-hosted BUILDSERVER tentacle onto Octopus-hosted Ubuntu workers and a Linux worker in the hub VNet.

The Windows image carries Azure CLI, PowerShell 7, Python and 7-Zip. The Ubuntu image took on a much broader toolset on top of that: the Az PowerShell module, `azure.datafactory.tools`, Octopus CLI, `Octopus.Client`, the .NET SDK and Node.js. That list was borrowed from what Octopus's own `worker-tools` images include, which are deliberately broad because they serve every Octopus customer. The result is a 736 MB image (tag `2026.0`).

A scan of the 16 active step templates and 16 script modules in the Octopus Web space found that the steps call only three things: the `az` CLI (8 templates and 16 modules), Bicep through `az deployment` (templates 902, 962 and 1121), and PowerShell 7 built-ins such as `Invoke-RestMethod` and `Compress-Archive`. One module, Copy-StorageContainers, expects `azcopy` but has no callers. Nothing calls the Az module, Data Factory tools, Octopus CLI, `Octopus.Client`, Python, 7-Zip, Node or the .NET SDK. The only Windows-era holdover is a commented-out AzureRM call in a module whose callers are all disabled.

The cost of the unused tools is paid on every run. Octopus-hosted dynamic workers are destroyed after 60 minutes idle or 72 hours of age, and Octopus pulls the execution image on each fresh worker, so roughly 500 MB of unused layers is downloaded repeatedly. The Az module also adds import time to every PowerShell step whether or not the step uses it.

The image was also missing two things the steps do need. Bicep was not pre-installed, so `az` downloads it on first use inside every fresh container. `azcopy` was absent.

## Decision

We will trim `octo-deploy-ubuntu` to the tools the Octopus steps actually call, and add tools back only when a step needs them.

The image keeps: the pinned `ubuntu:26.04` base digest, the base utilities and .NET runtime dependencies that Calamari requires (ICU, OpenSSL, krb5), PowerShell 7.6.4 from the GitHub release tarball, and Azure CLI 2.90.0 from Microsoft's apt feed, each verified against its pinned version at build time.

The image adds: Bicep as a pinned binary at `/usr/local/bin/bicep`, with `az` configured to use the binary from PATH and skip its version check, so `az deployment` never downloads anything at run time; and `azcopy` as a pinned static binary at `/usr/local/bin/azcopy`.

The image removes: the Az PowerShell module, `azure.datafactory.tools`, Octopus CLI, `Octopus.Client`, Python and pip, 7-Zip, Node.js and the .NET SDK, together with their build arguments and environment settings.

The image stays on Ubuntu 26.04. It continues to be built and pushed by hand to Docker Hub as `cmnhospitals/octo-deploy-ubuntu`, tagged `<year>.<release number that year>` (zero-based), so the trimmed image ships as `2026.1`. A GitHub Actions build workflow is a later change derived from the manual steps.

Alternatives considered:

- Keeping the broad toolset. Rejected: it is paid for on every worker lease and every PowerShell step, and nothing uses it.
- Using Octopus's `octopusdeploy/worker-tools` image directly instead of maintaining a custom one. Rejected: a custom image lets us include exactly what the steps need and exclude what they do not, and pin every version ourselves.

## Consequences

Positive:

- A much smaller pull on every fresh worker lease, so the first step of a deployment starts sooner.
- No Bicep download inside the container on first use, and no Az module import on every PowerShell step.
- Every tool in the image has a known caller, so the Dockerfile documents what the deployment steps depend on.

Negative:

- Any step that needs a removed tool fails at run time until the image is rebuilt and retagged with that tool added. Today no Web space step is affected, because none calls the removed tools. The Database space Flyway projects, APIManagement, DataAPIBuilder and the Data Factory runbooks run on BUILDSERVER or on `worker-tools` and are unaffected now, but moving any of them onto this image later means an image change first (for example `azure.datafactory.tools` for Data Factory, or Redgate CLIs for subset and mask).
- The image diverges further from the Windows image's tool list (Python and 7-Zip are gone), so the two are no longer interchangeable for a step that happens to use those. No active step does.
