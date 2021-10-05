# escape=`

FROM mcr.microsoft.com/windows/servercore:ltsc2019
SHELL ["powershell", "-Command"]

ARG Azure_Cli_Version=2.14.0
ARG Azure_Powershell_Version=4.5.0
ARG Octopus_Cli_Version=7.4.1
ARG Octopus_Client_Version=8.8.3
ARG Powershell_Version=7.0.6
ARG Python_Version=3.8.5
ARG ScriptCs_Version=0.17.1
ARG 7Zip_Version=19.0


# Install Choco
RUN $ProgressPreference = 'SilentlyContinue'; `
    Set-ExecutionPolicy Bypass -Scope Process -Force; `
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install dotnet 3.1+
# RUN Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -outFile 'dotnet-install.ps1'; `
#     [Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine'); `
#     .\dotnet-install.ps1 -Channel '3.1'; `
#     rm dotnet-install.ps1

# Install Azure CLI
RUN choco install azure-cli -y --version $Env:Azure_Cli_Version --no-progress


# # Install NodeJS
#RUN choco install nodejs-lts -y --version $Env:Node_Version --no-progress

# # Install python
RUN choco install -y python3 --version $Env:Python_Version --no-progress; `
    refreshenv

# # Install ScriptCS
# RUN choco install scriptcs -y --version $Env:ScriptCs_Version --no-progress

# # Install 7ZIP
RUN choco install 7zip -y --no-progress


# # Install octo
# RUN choco install octopustools -y --version $Env:Octopus_Cli_Version --no-progress

# # Install Octopus Client
# RUN Install-Package Octopus.Client -source https://www.nuget.org/api/v2 -SkipDependencies -Force -RequiredVersion $Env:Octopus_Client_Version

# # Install Powershell Core
RUN choco install powershell-core --yes --version $Env:Powershell_Version --no-progress


#Install Azure PowerShell modules
# https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-3.6.1
# RUN Install-Module -Force -Name Az -AllowClobber -Scope AllUsers -MaximumVersion $Env:Azure_Powershell_Version; `
#     Enable-AzureRmAlias -Scope LocalMachine

# # Update path for new tools
# ADD .\scripts\update_path.cmd C:\update_path.cmd
# RUN .\update_path.cmd;