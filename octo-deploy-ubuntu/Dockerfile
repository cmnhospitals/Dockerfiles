# Built on Ubuntu 26.04 LTS (Resolute Raccoon), pinned by digest for reproducible builds.
# Refresh the digest with:
#   docker buildx imagetools inspect ubuntu:26.04
FROM ubuntu:26.04@sha256:cd21a4f68a617580279d4b091cb18e3af9fa8a87500665f0ae5f7f757d17d367

ARG Image_Version=2026.0

LABEL org.opencontainers.image.title="octo-deploy-ubuntu" \
      org.opencontainers.image.description="Ubuntu image with Azure CLI, PowerShell Core, Python, 7-Zip, Octopus CLI, Az PowerShell modules, .NET SDK, and Node.js for Octopus Deploy workers" \
      org.opencontainers.image.source="https://github.com/cmnhospitals/Dockerfiles" \
      org.opencontainers.image.version=$Image_Version

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Parity with octo-deploy-windows (same ARG names, same defaults where the Linux
# package feed offers them). Azure CLI: the packages.microsoft.com feed for Ubuntu
# 26.04 only publishes 2.90.0+, so it runs ahead of the Windows image's 2.88.0.
ARG Azure_Cli_Version=2.90.0
ARG Powershell_Version=7.6.4
# Named SevenZip_Version rather than the Windows image's 7Zip_Version: shell variable names cannot start with a digit.
ARG SevenZip_Version=26.02

# Ubuntu-only tooling (not present in the Windows image)
ARG Azure_Powershell_Version=14.3.0
ARG Azure_DataFactory_Tools_Version=1.13.0
ARG Octopus_Cli_Version=9.0.0
ARG Octopus_Client_Version=17.1.2309
ARG Dotnet_Sdk_Version=10.0
ARG Node_Major_Version=22

ARG DEBIAN_FRONTEND=noninteractive

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    # Ubuntu's python3 is "externally managed" (PEP 668) and refuses plain `pip install`.
    # The Windows image's Python has no such guard, so opt out here for the same behaviour.
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PIP_NO_CACHE_DIR=1

# Base utilities and .NET runtime dependencies (PowerShell and Octopus.Client are .NET apps)
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
        wget \
        xz-utils \
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

# Install Python 3 with pip and venv from the Ubuntu archive. groff is needed for `az` help pages.
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip python3-venv groff && \
    ln -sf /usr/bin/python3 /usr/local/bin/python && \
    ln -sf /usr/bin/pip3 /usr/local/bin/pip && \
    rm -rf /var/lib/apt/lists/* && \
    python --version && pip --version

# Install 7-Zip from the official Linux build on 7-zip.org, pinned to the same version as the
# Windows image. The archive name drops the dot from the version (26.02 -> 7z2602). The
# upstream binary is `7zz`; `7z` is symlinked so scripts written against p7zip or Windows
# `7z.exe` work unchanged.
# https://www.7-zip.org/download.html
RUN curl -sSfL "https://www.7-zip.org/a/7z${SevenZip_Version//./}-linux-x64.tar.xz" -o /tmp/7z.tar.xz && \
    mkdir -p /opt/7zip && \
    tar xJf /tmp/7z.tar.xz -C /opt/7zip && \
    ln -s /opt/7zip/7zz /usr/local/bin/7zz && \
    ln -s /opt/7zip/7zz /usr/local/bin/7z && \
    rm /tmp/7z.tar.xz && \
    7z i | grep -q "7-Zip (z) ${SevenZip_Version}"

# Install Octopus CLI (`octo`) from the self-contained tarball. The octopuscli deb on apt.octopus.com
# depends on libssl1.1, libicu<=67 and liblttng-ust0, none of which exist in Ubuntu 24.04 or later,
# so it is uninstallable here. The tarball is a self-contained .NET single-file build that only
# needs the runtime dependencies installed above.
# https://octopus.com/downloads/octopuscli#linux
RUN curl -sSfL "https://download.octopusdeploy.com/octopus-tools/${Octopus_Cli_Version}/OctopusTools.${Octopus_Cli_Version}.linux-x64.tar.gz" -o /tmp/octo.tar.gz && \
    mkdir -p /opt/octo && \
    tar zxf /tmp/octo.tar.gz -C /opt/octo && \
    chmod +x /opt/octo/octo && \
    ln -s /opt/octo/octo /usr/local/bin/octo && \
    rm /tmp/octo.tar.gz && \
    octo version | grep -q "^${Octopus_Cli_Version}"

# Install Octopus.Client (netstandard2.0 assemblies copied to / so `Add-Type -Path /Octopus.Client.dll` keeps working)
# https://octopus.com/docs/octopus-rest-api/octopus.client
RUN pwsh -NoLogo -Command 'Install-Package -Force Octopus.Client -RequiredVersion "'${Octopus_Client_Version}'" -Source https://www.nuget.org/api/v2 -SkipDependencies -Scope AllUsers' && \
    octopusClientPackagePath=$(pwsh -NoLogo -Command '(Get-Item ((Get-Package Octopus.Client).Source)).Directory.FullName') && \
    cp -r "${octopusClientPackagePath}/lib/netstandard2.0/"* /

# Install Az PowerShell modules
# https://learn.microsoft.com/powershell/azure/install-azps-linux
RUN pwsh -NoLogo -Command 'Install-Module -Force -Name Az -AllowClobber -Scope AllUsers -RequiredVersion "'${Azure_Powershell_Version}'"'

# Install Azure Data Factory Tools
# https://www.powershellgallery.com/packages/azure.datafactory.tools
RUN pwsh -NoLogo -Command 'Install-Module -Force -Name azure.datafactory.tools -Scope AllUsers -RequiredVersion "'${Azure_DataFactory_Tools_Version}'"'

# Install the .NET SDK from the Ubuntu archive (Canonical builds). .NET 8 is not packaged for
# Ubuntu 26.04 by either Canonical or packages.microsoft.com, so this tracks the current LTS.
# https://learn.microsoft.com/dotnet/core/install/linux-ubuntu-install?pivots=os-linux-ubuntu-2604
RUN apt-get update && \
    apt-get install -y --no-install-recommends "dotnet-sdk-${Dotnet_Sdk_Version}" && \
    rm -rf /var/lib/apt/lists/* && \
    dotnet --version

# Install Node.js LTS from NodeSource (Node 20 reached end of life in April 2026)
# https://github.com/nodesource/distributions
RUN curl -sSfL "https://deb.nodesource.com/setup_${Node_Major_Version}.x" | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    node --version | grep -q "^v${Node_Major_Version}\."

# Clean up temp files and caches to keep image size down
RUN rm -rf /tmp/* /var/tmp/* /root/.cache /root/.nuget /root/.local/share/PowerShell/PowerShellGet
