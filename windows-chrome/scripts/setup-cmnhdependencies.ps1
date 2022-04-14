# Net Framework

# Install dotnet 3.1+ and 5.0
Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -outFile 'dotnet-install.ps1'; 
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine'); 
.\dotnet-install.ps1 -Channel '3.1'
.\dotnet-install.ps1 -Channel '5.0'
.\dotnet-install.ps1 -Channel '2.1'

mkdir 'C:\src';

#VOLUME C:\\src

#mkdir 'C:\Tools';

setx /M PATH $($Env:PATH + ';'+$Env:dotnetOctoPath+';C:\Users\ContainerAdministrator\AppData\Local\Microsoft\dotnet');

# Local deploy
Install-PackageProvider -Name NuGet -Force;
Install-Module -Name PowerShellGet -Force;

Register-PackageSource -Name CmnhMyGet -Location https://www.myget.org/F/cmnhospitals/api/v2 -ProviderName PowerShellGet -Trusted;
Install-Module LocalDeploy -Force -Scope CurrentUser;
# Az modules
Install-Module Az -Force -Scope CurrentUser;

