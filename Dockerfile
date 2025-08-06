## This creates a TIBCO BWCE image with the following features
## - TIBCO BWCE 2.10.0  
## - TIBCO BWCE 2.10.0 HF 003
## - TIBCO BWCE 2.10.0 Maven plugin (including installation of maven dependencies)
## - TIBCO Platform CLI (tibcop) 
## - Apache Maven 3.9.1 0

## software required for the build in resources/bwce-studio directory (for BWCE 2.10.0 HF 003 version)
## TIB_BWCE_2.10.0_linux26_x86_64.zip
## TIB_BWCE_2.10.0_HF_003.zip 
## TIBCOUniversalInstaller_bwce_2.10.0.silent
## product_tibco_eclipse_lgpl_4.4.1.001_linux26gl25_x86_64.zip


## build docker base a bwce base image fro with the following command
## docker build -t bwce-base:2.10.0-hf003 . 

FROM alpine:latest AS builder

ADD resources/binaries/bwce /software
ADD resources/binaries/platform /platform
ADD resources/scripts /scripts
ADD resources/project /project
 
FROM debian:bookworm-slim AS bwce-base

ARG MAVEN_URL=https://dlcdn.apache.org/maven/maven-3
ARG MAVEN_VERS=3.9.11
ARG BWCE_VERS=2.10.0
ARG BWCE_HF=003
ARG PLATFORM_CLI_VERS=0.9.0

# Install system dependencies
RUN apt-get update && \
    apt-get --no-install-recommends install -y \
    ca-certificates \
    curl \
    gettext \
    net-tools \
    procps \
    unzip \
    xsltproc \
    xmlstarlet \
    libsecret-1-dev \
    libgtk-3-0 \
     # X virtual framebuffer and additional packages for running GUI based applications 
     # in a headless environment for executing bwdesign
    xvfb \                 
    x11-utils \
    libgl1 \
    dbus-x11 \
    at-spi2-core \
    xterm

# setting up DISPLAY environment variable for Xvfb
ENV DISPLAY=:99
# installing entrypoint script and setting up permissions for xvfb
RUN --mount=type=bind,target=/scripts,source=/scripts,from=builder \
    cp /scripts/entrypoint.sh /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh && \
    mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
    
# Create tibco user and directories
RUN groupadd --gid 1000 -r tibco && \
    useradd --uid 1000 -r -m -g tibco tibco

RUN mkdir -p /opt/tibco
RUN chown -R tibco:tibco /opt/tibco 

# Install Maven
RUN curl -fsSL -o /tmp/apache-maven.tar.gz ${MAVEN_URL}/${MAVEN_VERS}/binaries/apache-maven-${MAVEN_VERS}-bin.tar.gz && \
    mkdir -p /usr/share/maven /usr/share/maven/ref && \
    tar -xvzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 && \
    rm -f /tmp/apache-maven.tar.gz && \
    ln -fs /usr/share/maven/bin/mvn /usr/bin/mvn

USER tibco

ENV JAVA_HOME=/opt/tibco/bwce/tibcojre64/17 \
    MAVEN_HOME=/usr/share/maven \
    MAVEN_CONFIG=/home/tibco/.m2

# Install BWCE
RUN --mount=type=bind,target=/software,source=/software,from=builder \
    mkdir -p /opt/tibco/install && \
     cd /opt/tibco/install && \
     unzip /software/TIB*linux26*.zip  && \
     cp /software/TIBCOUniversalInstaller_bwce_*.silent responsefile.silent && \
     mkdir -p /opt/tibco/install/3rdParty && \
     cp /software/product_tibco_eclipse_lgpl_4.4.1.001_linux26gl25_x86_64.zip /opt/tibco/install/3rdParty && \
     rm TIBCOUniversalInstaller_*.silent && \
     chmod +x TIBCOUniversalInstaller*.bin && \
     ./TIBCOUniversalInstaller-*.bin -silent -V responsefile.silent && \
     rm -fr /opt/tibco/install && \
     echo "export PATH=\$PATH:/opt/tibco/bwce/bwce/2.10/bin" >> /home/tibco/.bashrc

## Install BWCE HF     
RUN --mount=type=bind,target=/software,source=/software,from=builder \
    mkdir -p /opt/tibco/install && \
    cd /opt/tibco/install && \
    unzip /software/TIB*HF-${BWCE_HF}.zip && \
    rm TIBCOUniversalInstaller.silent && \
    cp /software/TIBCOUniversalInstaller_bwce_*.silent responsefile.silent && \
    cp /opt/tibco/bwce/tools/universal_installer/TIBCOUniversalInstaller-lnx-x86-64.bin /opt/tibco/install && \
    ./TIBCOUniversalInstaller-*.bin -silent -V responsefile.silent && \
    rm -fr /opt/tibco/install   

## Install platform cli
# RUN --mount=type=bind,target=/platform,source=/platform,from=builder \
#     mkdir -p /opt/tibco/platform && \
#     tar -xf /platform/tibcop-cli-${PLATFORM_CLI_VERS}-linux-x64.tar.gz -C /opt/tibco/platform  && \
#     echo "export PATH=\$PATH:/opt/tibco/platform/tibcop/bin:/opt/tibco/bwce/tibcojre64/17/bin" >> /home/tibco/.bashrc

## Install BWCE components into maven cache
RUN cd /opt/tibco/bwce/bwce/*/maven && \
    bash ./install.sh

# mount sample bwce project and execute maven targets to download dependencies into image
# this will reduce execution time during pipeline runs
RUN --mount=type=bind,target=/project,source=/project,from=builder \
    mkdir -p /opt/tibco/build && \
    cp -r /project/* /opt/tibco/build && \
    cd /opt/tibco/build/*.parent && \
    (mvn clean package || echo "skipped error") && \
    (mmvn dependency:get -Dartifact=org.codehaus.mojo:build-helper-maven-plugin:3.6.1 || echo "skipped error") && \
    (mvn dependency:get -Dartifact=com.tibco.plugins:bw6-maven-plugin:2.10.3 || echo "skipped error") && \
    rm -r /opt/tibco/build  


# ## replace bwdesign.tra (adding some extended properties)
# RUN --mount=type=bind,target=/software,source=/software,from=builder \
#     cp /software/config/bwdesign.tra /opt/tibco/bwce/bwce/2.10/bin/bwdesign.tra && \
#     chmod 644 /opt/tibco/bwce/bwce/2.10/bin/bwdesign.tra

WORKDIR /project

## use entry point only if container is used to automatically start a BWCE application. 
## Not to be used for CICD puproses where the command to execute is provided by the CICD pipeline tasks
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["xterm", "-e", "bash -c 'echo \"Xvfb is running and xterm is launched for 5 seconds\"; sleep 5; exit'"]


