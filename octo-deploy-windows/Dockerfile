# escape=`

# Built on ltsc2019 servercore, with .NET Framework 4.8 preinstalled (Chocolatey CLI 2.x requires
# 4.8; the plain servercore image only ships 4.7.2, forcing a slow in-container Framework upgrade
# with an unresolved "reboot required" step). Refresh the digest with:
#   docker buildx imagetools inspect mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019
FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019@sha256:266a560ada0514d9700076e2d08fd8d308770c77a6d8492c2096220c2de5b54d

ARG Image_Version=2026.0

LABEL org.opencontainers.image.title="octo-deploy-windows" `
      org.opencontainers.image.description="Windows Server Core image with Azure CLI, PowerShell Core, Python, and 7-Zip for Octopus Deploy workers" `
      org.opencontainers.image.source="https://github.com/cmnhospitals/Dockerfiles" `
      org.opencontainers.image.version=$Image_Version

SHELL ["powershell", "-Command"]

ARG Azure_Cli_Version=2.88.0
ARG Powershell_Version=7.6.4
ARG Python_Version=3.13.8
ARG Chocolatey_Version=2.7.3
ARG 7Zip_Version=26.2.0

# Install Choco
RUN $ProgressPreference = 'SilentlyContinue'; `
    Set-ExecutionPolicy Bypass -Scope Process -Force; `
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
    $env:chocolateyVersion = $Env:Chocolatey_Version; `
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Azure CLI
RUN choco install azure-cli -y --version $Env:Azure_Cli_Version --no-progress; `
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) { throw "choco install azure-cli failed with exit code $LASTEXITCODE" }

# Install Python from python.org's embeddable zip (no installer at all). Chocolatey's python3
# package pulls in a vcredist140/vcredist2015 dependency chain whose Burn-bootstrapper .exe
# deadlocks in this environment (process alive, ~0% CPU, never completes). The official full
# installer (python-*-amd64.exe) is the same Burn bootstrapper technology and hangs identically,
# so the zip distribution is used instead, with pip bootstrapped manually via get-pip.py.
RUN $ProgressPreference = 'SilentlyContinue'; `
    New-Item -ItemType Directory -Path 'C:\Python' -Force | Out-Null; `
    Invoke-WebRequest "https://www.python.org/ftp/python/$Env:Python_Version/python-$Env:Python_Version-embed-amd64.zip" -OutFile 'C:\python-embed.zip'; `
    Expand-Archive -Path 'C:\python-embed.zip' -DestinationPath 'C:\Python' -Force; `
    Remove-Item 'C:\python-embed.zip' -Force; `
    $pthFile = (Get-ChildItem 'C:\Python\python*._pth')[0].FullName; `
    (Get-Content $pthFile) -replace '^#import site', 'import site' | Set-Content $pthFile; `
    Invoke-WebRequest 'https://bootstrap.pypa.io/get-pip.py' -OutFile 'C:\Python\get-pip.py'; `
    & 'C:\Python\python.exe' 'C:\Python\get-pip.py' --no-warn-script-location; `
    if ($LASTEXITCODE -ne 0) { throw "get-pip.py failed with exit code $LASTEXITCODE" }; `
    Remove-Item 'C:\Python\get-pip.py' -Force; `
    [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\Python;C:\Python\Scripts', 'Machine')

# Install 7ZIP
RUN choco install 7zip -y --version $Env:7Zip_Version --no-progress; `
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) { throw "choco install 7zip failed with exit code $LASTEXITCODE" }

# Install Powershell Core
RUN choco install powershell-core --yes --version $Env:Powershell_Version --no-progress; `
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) { throw "choco install powershell-core failed with exit code $LASTEXITCODE" }

# Clean up Chocolatey cache and temp installers to keep image size down
RUN Remove-Item -Recurse -Force "$env:ChocolateyInstall\lib-bad" -ErrorAction SilentlyContinue; `
    Remove-Item -Recurse -Force "$env:TEMP\*" -ErrorAction SilentlyContinue