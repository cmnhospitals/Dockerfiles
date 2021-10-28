FROM mcr.microsoft.com/windows/servercore:ltsc2019
ARG Node_Version=14.17.5
SHELL ["powershell", "-Command"]

# Install Choco
RUN $ProgressPreference = 'SilentlyContinue'; \
    Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# # Install NodeJS
RUN choco install nodejs-lts -y --version $Env:Node_Version --no-progress

COPY ./scripts/* ./

#Install google chrome
RUN .\setup-chrome.ps1

ENV dotnetOctoPath="C:\\Users\\ContainerAdministrator\\.dotnet\\tools"

# RUN mkdir C:\\src

# #VOLUME C:\\src


# RUN mkdir C:\\Tools



#RUN mkdir C:\\Tools\\dotnet-octo

RUN .\setup-cmnhdependencies.ps1

#ADD .\scripts\update_path.cmd C:\update_path.cmd
#RUN cmd /c .\update_path.cmd;

RUN rm .\*.ps1 
#RUN rm .\update_path.cmd



#ENV PATH="${PATH};C:\\Users\\ContainerAdministrator\\AppData\\Local\\Microsoft\\dotnet;C:\\Tools\\dotnet-octo;"  

# RUN setx /M PATH $($Env:PATH + ';'+$Env:dotnetOctoPath+';C:\Users\ContainerAdministrator\AppData\Local\Microsoft\dotnet')

# dotnet-octo
# RUN dotnet tool install --global Octopus.Dotnet.Cli

ENV DOTNET_ROOT="C:\\Users\\ContainerAdministrator\\AppData\\Local\\Microsoft\\dotnet"
#RUN echo $Env:DOTNET_ROOT
RUN echo $Env:Path
RUN dotnet nuget add source https://api.nuget.org/v3/index.json --name nuget
RUN dotnet tool install Octopus.Dotnet.Cli --tool-path $Env:dotnetOctoPath
RUN dotnet nuget add source https://www.myget.org/F/cmnhospitals/api/v3/index.json --name cmnh
#RUN echo $Env:PATH
#RUN echo $Env:dotnetOctoPath

WORKDIR C:\\src

#ENTRYPOINT [ "powershell.exe" ]