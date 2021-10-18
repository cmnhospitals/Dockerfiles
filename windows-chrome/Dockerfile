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

COPY ./scripts/* .

#Install google chrome
RUN .\setup-chrome.ps1

RUN rm .\*.ps1


RUN mkdir C:\\src

VOLUME C:\\src

WORKDIR C:\\src

ENTRYPOINT [ "powershell.exe" ]