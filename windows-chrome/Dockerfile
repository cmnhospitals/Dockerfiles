FROM mcr.microsoft.com/windows/servercore:ltsc2019
SHELL ["powershell", "-Command"]
ENV dotnetOctoPath="C:\\Users\\ContainerAdministrator\\.dotnet\\tools"
ENV DOTNET_ROOT="C:\\Users\\ContainerAdministrator\\AppData\\Local\\Microsoft\\dotnet"
ARG DOTNET_VERSION=5.0

# Install google chrome and .NET
RUN $Path = $env:TEMP; \
    $Installer = 'chrome_installer.exe'; \
    Invoke-WebRequest 'http://dl.google.com/chrome/chrome_installer.exe' -OutFile $Path\$Installer; \
    Start-Process -FilePath $Path\$Installer -Args '/silent /install' -Verb RunAs -Wait; \
    Remove-Item $Path\$Installer; \
    # Net Framework
    Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -outFile 'dotnet-install.ps1'; \
    # Install dotnet 
    [Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine'); \
    .\dotnet-install.ps1 -Channel $Env:DOTNET_VERSION; \
    #Setting up the src dir to mount the volume outside the container
    mkdir 'C:\src'; \
    rm .\dotnet-install.ps1;

RUN setx /M PATH $($Env:PATH + ';'+$Env:dotnetOctoPath+';C:\Users\ContainerAdministrator\AppData\Local\Microsoft\dotnet')

ARG CMNH_MYGET_URL=https://www.myget.org/F/cmnhospitals/api/v2
# Local deploy and Az modules setup, along with dotnet tools
RUN Install-PackageProvider -Name NuGet -Force; \
    Install-Module -Name PowerShellGet -Force; \
    Register-PackageSource -Name CmnhMyGet -Location $Env:CMNH_MYGET_URL -ProviderName PowerShellGet -Trusted; \
    # Az modules
    Install-Module Az -Force -Scope CurrentUser;

ARG CMNH_NUGET_SOURCE=https://www.myget.org/F/cmnhospitals/api/v3/index.json
ARG DOTNET_OCTO_VERSION=7.4.3487
# Preparing nuget sources and adding octopus cli tool
RUN dotnet nuget add source https://api.nuget.org/v3/index.json --name nuget; \
    dotnet nuget add source $Env:CMNH_NUGET_SOURCE --name cmnh; \
    dotnet tool install Octopus.Dotnet.Cli --tool-path $Env:dotnetOctoPath --version $Env:DOTNET_OCTO_VERSION;

ARG LOCAL_DEPLOY_VERSION=2.10.36
RUN Install-Module LocalDeploy -Force -Scope CurrentUser -RequiredVersion $Env:LOCAL_DEPLOY_VERSION;

ARG NODE_VERSION=14.17.5
RUN $ProgressPreference = 'SilentlyContinue'; \
    Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    # # Install NodeJS
    choco install nodejs-lts -y --version $Env:NODE_VERSION --no-progress;

WORKDIR C:\\src
