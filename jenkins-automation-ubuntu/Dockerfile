FROM node:lts-alpine3.12
ENV dotnetInstallPath=/usr/share/dotnet
# install the requirements alongside powershell
RUN apk add libgdiplus --repository https://dl-3.alpinelinux.org/alpine/edge/testing/ \
    && apk add --no-cache \
    bash \
    ca-certificates \
    less \
    ncurses-terminfo-base \
    krb5-libs \
    libgcc \
    libintl \
    libssl1.1 \
    libstdc++ \
    tzdata \
    userspace-rcu \
    zlib \
    icu-libs \
    curl \
    && apk -X https://dl-cdn.alpinelinux.org/alpine/edge/main add --no-cache \
    lttng-ust \
# Download the powershell '.tar.gz' archive
    && curl -L https://github.com/PowerShell/PowerShell/releases/download/v7.2.0-preview.10/powershell-7.2.0-preview.10-linux-alpine-x64.tar.gz -o /tmp/powershell.tar.gz \
# Create the target folder where powershell will be placed
    &&  mkdir -p /opt/microsoft/powershell/7 \
# Expand powershell to the target folder
    &&  tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 \
# Set execute permissions
    &&  chmod +x /opt/microsoft/powershell/7/pwsh \
# Create the symbolic link that points to pwsh
    &&  ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh

RUN mkdir /src 
#RUN mkdir ${dotnetOctoPath}

VOLUME /src

WORKDIR /src

# Making sure we have LocalDeploy installed at least a base version at the time of the build
RUN pwsh -Command "Register-PackageSource -Name CmnhMyGet -Location https://www.myget.org/F/cmnhospitals/api/v2 -ProviderName PowerShellGet -Trusted" 

RUN pwsh -Command "Install-Module LocalDeploy -Force -Scope CurrentUser"

# Installing dotnet tooling 
ADD /scripts/* .
RUN ./dotnet-install.sh -c 5.0 --install-dir ${dotnetInstallPath} \
#--install-dir ${dotnetInstallPath} \
    && ln -s ${dotnetInstallPath}/dotnet /usr/bin/dotnet
#RUN rm dotnet-install.sh

#Installing dotnet-octo
#RUN pwsh -c "dotnet tool install -g Octopus.DotNet.Cli" 
# --tool-path ${dotnetOctoPath}"

ENV dotnetOctoPath=/root/.dotnet/tools
# Adding the dotnet global tools to the path
ENV PATH="${dotnetOctoPath}:${PATH}"  


ENTRYPOINT [ "pwsh" ]