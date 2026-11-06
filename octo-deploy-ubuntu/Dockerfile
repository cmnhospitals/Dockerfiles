# Built on Ubuntu 26.04 LTS (Resolute Raccoon), pinned by digest for reproducible builds.
# Refresh the digest with:
#   docker buildx imagetools inspect ubuntu:26.04
FROM ubuntu:26.04@sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c

ARG Image_Version=2026.1

LABEL org.opencontainers.image.title="octo-deploy-ubuntu" \
      org.opencontainers.image.description="Ubuntu image with PowerShell Core, Azure CLI, Bicep and AzCopy for Octopus Deploy workers" \
      org.opencontainers.image.source="https://github.com/cmnhospitals/Dockerfiles" \
      org.opencontainers.image.version=$Image_Version

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The image carries only what the Octopus step templates and script modules call.
# See doc/adr/0001 for what was removed and why. Azure CLI: the packages.microsoft.com
# feed for Ubuntu 26.04 only publishes 2.90.0+, so it runs ahead of the Windows image's 2.88.0.
ARG Azure_Cli_Version=2.90.0
ARG Powershell_Version=7.6.4
ARG Bicep_Version=0.48.1
ARG Azcopy_Version=10.34.1

ARG DEBIAN_FRONTEND=noninteractive

# Azure CLI normally downloads Bicep into ~/.azure/bin on first use. Point it at the
# binary installed below instead, and stop it checking for newer versions, so no step
# ever downloads Bicep at run time. These are the env-var forms of
# `az config set bicep.use_binary_from_path=true` and `bicep.check_version=false`.
ENV AZURE_BICEP_USE_BINARY_FROM_PATH=true \
    AZURE_BICEP_CHECK_VERSION=false

# Base utilities and .NET runtime dependencies (PowerShell and Octopus's Calamari are .NET apps)
# https://learn.microsoft.com/dotnet/core/install/linux-ubuntu#dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        libc6 \
        libgcc-s1 \
        libgssapi-krb5-2 \
        libicu78 \
        libssl3t64 \
        libstdc++6 \
        unzip \
        zlib1g && \
    rm -rf /var/lib/apt/lists/*

# Install PowerShell Core from the pinned GitHub release tarball. packages.microsoft.com
# does not publish a `powershell` deb for Ubuntu 26.04 (only for 22.04/24.04), and the
# tarball is Microsoft's documented route for that case. It also gives an exact version
# pin instead of whatever the apt feed happens to carry.
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

# Install Bicep from the pinned GitHub release binary. The deployment steps run
# `az deployment sub create --template-file *.bicep`, which needs Bicep on hand.
# The final check confirms `az` used this binary rather than downloading its own copy.
# https://github.com/Azure/bicep/releases
RUN curl -sSfL "https://github.com/Azure/bicep/releases/download/v${Bicep_Version}/bicep-linux-x64" -o /usr/local/bin/bicep && \
    chmod +x /usr/local/bin/bicep && \
    bicep --version | grep -q "${Bicep_Version}" && \
    az bicep version | grep -q "${Bicep_Version}" && \
    test ! -e /root/.azure/bin/bicep

# Install AzCopy from the pinned GitHub release tarball (static binary). Used by the
# Copy-StorageContainers script module.
# https://github.com/Azure/azure-storage-azcopy/releases
RUN curl -sSfL "https://github.com/Azure/azure-storage-azcopy/releases/download/v${Azcopy_Version}/azcopy_linux_amd64_${Azcopy_Version}.tar.gz" -o /tmp/azcopy.tar.gz && \
    tar zxf /tmp/azcopy.tar.gz -C /tmp && \
    mv /tmp/azcopy_linux_amd64_${Azcopy_Version}/azcopy /usr/local/bin/azcopy && \
    chmod +x /usr/local/bin/azcopy && \
    rm -rf /tmp/azcopy.tar.gz /tmp/azcopy_linux_amd64_${Azcopy_Version} && \
    azcopy --version | grep -q "${Azcopy_Version}"

# Clean up temp files and caches to keep image size down
RUN rm -rf /tmp/* /var/tmp/* /root/.cache /root/.azure
