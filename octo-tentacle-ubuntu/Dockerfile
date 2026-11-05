# Octopus Tentacle image with the deploy tools baked in, for the self-hosted worker that runs
# as an Azure Container Instance in the hub VNet. Container Instances cannot run Docker, so
# steps on this worker cannot use an execution container; the tools octo-deploy-ubuntu would
# have supplied are installed here instead. See doc/adr/0001.
#
# Base: Octopus's own Tentacle image (Ubuntu 24.04). Octopus publishes a build most days and
# `latest` follows it. The ACR task in acr-task.yaml rebuilds this image every night and
# restarts the worker onto it (doc/adr/0002).
FROM octopusdeploy/tentacle:latest

ARG Image_Version=2026.0

LABEL org.opencontainers.image.title="octo-tentacle-ubuntu" \
      org.opencontainers.image.description="Octopus Tentacle with PowerShell Core, Azure CLI, Bicep and AzCopy, for the hub worker container" \
      org.opencontainers.image.source="https://github.com/cmnhospitals/Dockerfiles" \
      org.opencontainers.image.version=$Image_Version

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Same tool list and pins as octo-deploy-ubuntu, so a step behaves the same on this worker as
# it does inside that execution container on a hosted worker.
ARG Azure_Cli_Version=2.90.0
ARG Powershell_Version=7.6.4
ARG Bicep_Version=0.48.1
ARG Azcopy_Version=10.34.1

ARG DEBIAN_FRONTEND=noninteractive

# Azure CLI normally downloads Bicep into ~/.azure/bin on first use. Point it at the
# binary installed below instead, and stop it checking for newer versions, so no step
# ever downloads Bicep at run time.
ENV AZURE_BICEP_USE_BINARY_FROM_PATH=true \
    AZURE_BICEP_CHECK_VERSION=false

# The base image already carries ca-certificates, curl, libicu74 and libssl3t64. Add the
# rest of the .NET runtime dependencies PowerShell needs, gnupg for the apt key, and unzip.
# https://learn.microsoft.com/dotnet/core/install/linux-ubuntu#dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gnupg \
        libgssapi-krb5-2 \
        libstdc++6 \
        unzip \
        zlib1g && \
    rm -rf /var/lib/apt/lists/*

# Install PowerShell Core from the pinned GitHub release tarball, the same route as
# octo-deploy-ubuntu, so the two images carry the same exact version. Octopus runs
# PowerShell steps on a Linux Tentacle through `pwsh` on PATH.
# https://learn.microsoft.com/powershell/scripting/install/install-ubuntu#installation-via-direct-download
RUN curl -sSfL "https://github.com/PowerShell/PowerShell/releases/download/v${Powershell_Version}/powershell-${Powershell_Version}-linux-x64.tar.gz" -o /tmp/powershell.tar.gz && \
    mkdir -p /opt/microsoft/powershell/7 && \
    tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && \
    chmod +x /opt/microsoft/powershell/7/pwsh && \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
    rm /tmp/powershell.tar.gz && \
    pwsh -NoLogo -Command '$PSVersionTable.PSVersion.ToString()' | grep -qx "${Powershell_Version}"

# Install Azure CLI from Microsoft's apt feed, pinned to the exact package version
# https://learn.microsoft.com/cli/azure/install-azure-cli-linux?pivots=apt
RUN . /etc/os-release && \
    mkdir -p /etc/apt/keyrings && \
    curl -sSfL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/azure-cli.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends "azure-cli=${Azure_Cli_Version}-1~${VERSION_CODENAME}" && \
    rm -rf /var/lib/apt/lists/* && \
    az version --output tsv --query '"azure-cli"' | grep -qx "${Azure_Cli_Version}"

# Install Bicep from the pinned GitHub release binary. The final check confirms `az` used
# this binary rather than downloading its own copy.
# https://github.com/Azure/bicep/releases
RUN curl -sSfL "https://github.com/Azure/bicep/releases/download/v${Bicep_Version}/bicep-linux-x64" -o /usr/local/bin/bicep && \
    chmod +x /usr/local/bin/bicep && \
    bicep --version | grep -q "${Bicep_Version}" && \
    az bicep version | grep -q "${Bicep_Version}" && \
    test ! -e /root/.azure/bin/bicep

# Install AzCopy from the pinned GitHub release tarball (static binary).
# https://github.com/Azure/azure-storage-azcopy/releases
RUN curl -sSfL "https://github.com/Azure/azure-storage-azcopy/releases/download/v${Azcopy_Version}/azcopy_linux_amd64_${Azcopy_Version}.tar.gz" -o /tmp/azcopy.tar.gz && \
    tar zxf /tmp/azcopy.tar.gz -C /tmp && \
    mv /tmp/azcopy_linux_amd64_${Azcopy_Version}/azcopy /usr/local/bin/azcopy && \
    chmod +x /usr/local/bin/azcopy && \
    rm -rf /tmp/azcopy.tar.gz /tmp/azcopy_linux_amd64_${Azcopy_Version} && \
    azcopy --version | grep -q "${Azcopy_Version}"

# Clean up. The base image's ENTRYPOINT (/scripts/configure-and-run.sh), WORKDIR and
# environment are inherited unchanged: this image starts a Tentacle exactly as the base does.
RUN rm -rf /tmp/* /var/tmp/* /root/.cache /root/.azure
