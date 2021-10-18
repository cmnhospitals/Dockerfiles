FROM ubuntu:20.04

RUN  apt update \
    && apt install -y unzip gnupg2 xvfb libxi6 libgconf-2-4 curl

RUN curl -sS -o - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add 
RUN  bash -c "echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' >> /etc/apt/sources.list.d/google-chrome.list" 
RUN  apt -y update \
     && apt -y install google-chrome-stable 

# Installing chrome

# RUN apt update \
#     && apt install -y wget fonts-liberation libasound2 libatk1.0-0 libatspi2.0-0 libcairo2 libcups2 \
#     libatk-bridge2.0-0 libcurl3-gnutls libcurl3-nss libcurl4 libdrm2 libgbm1  libgtk-3-0 \
#     libnspr4 libnss3 libpango-1.0-0 libxcomposite1 libxdamage1 libxfixes3 libxkbcommon0 libxrandr2 libxshmfence1 xdg-utils
# RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
#     && dpkg -i google-chrome-stable_current_amd64.deb  
#RUN apt-get install -f
# Install Node v14.x
#RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
#RUN apt install nodejs
RUN mkdir /src
VOLUME /src
WORKDIR /src
#RUN npm install -g n
#Setting up nvm

ENV NVM_DIR /usr/local/nvm 
# or ~/.nvm , depending
ENV NODE_VERSION 14.17.5

RUN mkdir $NVM_DIR
# Install nvm with node and npm
RUN curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH="${NVM_DIR}/versions/node/v${NODE_VERSION}/lib/node_modules"
ENV PATH="${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:${PATH}"

# get powershell for 20.04 
RUN apt-get update && \
    apt-get install -y wget unzip apt-utils curl software-properties-common && \
    wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    add-apt-repository universe && \
    apt-get install -y powershell

# Get .NET SDK 3.1 and 5
# https://docs.microsoft.com/en-us/dotnet/core/install/linux-package-manager-ubuntu-1804
#RUN DOTNET_CLI_TELEMETRY_OPTOUT=1 && \
#    echo "export DOTNET_CLI_TELEMETRY_OPTOUT=1" > /etc/profile.d/set-dotnet-env-vars.sh && \
#    apt-get install -y apt-transport-https && \
#    apt-get update && \
#    apt-get install -y dotnet-sdk-3.1 dotnet-sdk-5.0


# Making sure we have LocalDeploy installed at least a base version at the time of the build
#RUN pwsh -Command "Register-PackageSource -Name CmnhMyGet -Location https://www.myget.org/F/cmnhospitals/api/v2 -ProviderName PowerShellGet -Trusted" 

#RUN pwsh -Command "Install-Module LocalDeploy -Force -Scope CurrentUser"

#RUN pwsh -Command "Install-Module Az -Force -Scope CurrentUser -AllowClobber"

#Installing dotnet-octo
#RUN pwsh -c "dotnet tool install -g Octopus.DotNet.Cli"
# --tool-path ${dotnetOctoPath}"

#ENV dotnetOctoPath=/root/.dotnet/tools
#ENV PATH="${dotnetOctoPath}:${PATH}"  
