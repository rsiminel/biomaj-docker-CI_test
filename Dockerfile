FROM debian:bullseye

WORKDIR /root
ENV BIOMAJ_CONFIG=/root/config.yml
ENV prometheus_multiproc_dir=/tmp/biomaj-prometheus-multiproc

RUN rm -rf /tmp/biomaj-prometheus-multiproc && \
    mkdir -p /tmp/biomaj-prometheus-multiproc

# Install docker to allow docker execution from process-message
RUN buildDeps='gnupg2 dirmngr' \
    && apt-get update \
    && apt-get install -y apt-transport-https curl libcurl4-openssl-dev python3-pycurl python3-setuptools python3-pip git unzip bzip2 ca-certificates jq $buildDeps --no-install-recommends \
    && echo 'deb [arch=amd64] https://download.docker.com/linux/debian buster stable' | tee /etc/apt/sources.list.d/docker.list \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
    && apt-get update \
    && apt-get install --no-install-recommends -y docker-ce-cli \
    && apt-get purge -y --auto-remove $buildDeps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV BIOMAJ_RELEASE="shahikorma-v13"

RUN git clone https://github.com/genouest/biomaj-process.git && \
    git clone https://github.com/genouest/biomaj-download.git

ENV BIOMAJ_CONFIG=/etc/biomaj/config.yml

RUN mkdir -p /var/log/biomaj

RUN pip3 install --no-cache-dir pip --upgrade && \
    pip3 install --no-cache-dir setuptools --upgrade && \
    pip3 install --no-cache-dir greenlet==0.4.17 && \
    pip3 install --no-cache-dir graypy && \
    pip3 install --no-cache-dir pymongo==3.12.3 && \
    pip3 install --no-cache-dir redis==3.5.3 && \
    pip3 install --no-cache-dir wheel && \
    pip3 install --no-cache-dir PyYAML==5.4.1 && \
    pip3 install --no-cache-dir protobuf==3.20.3 && \
    python3 -m pip install --no-cache-dir ftputil

ENV SUDO_FORCE_REMOVE=yes
RUN buildDeps="gcc python3-dev protobuf-compiler" \
    && set -x \
    && apt-get update \
    && apt-get install -y $buildDeps --no-install-recommends \
    && pip install git+https://github.com/genouest/biomaj-core.git --no-cache-dir \
    && pip install git+https://github.com/genouest/biomaj-zipkin.git --no-cache-dir \
    && pip install git+https://github.com/genouest/biomaj-user.git --no-cache-dir \
    && pip install git+https://github.com/genouest/biomaj-cli.git --no-cache-dir \
    && cd /root/biomaj-process/biomaj_process/message && protoc --python_out=. procmessage.proto \
    && pip install git+https://github.com/genouest/biomaj-process.git --no-cache-dir \
    && cd /root/biomaj-download/biomaj_download/message && protoc --python_out=. downmessage.proto \
    && pip install git+https://github.com/genouest/biomaj-download.git --no-cache-dir \
    && pip install git+https://github.com/genouest/biomaj.git --no-cache-dir \
    && pip install git+https://github.com/genouest/biomaj-daemon.git --no-cache-dir \
    && pip install git+https://github.com/genouest/biomaj-watcher.git --no-cache-dir \
    && pip install git+https://github.com/genouest/biomaj-ftp.git --no-cache-dir \
    && pip install git+https://github.com/genouest/biomaj-release.git --no-cache-dir \
    && pip install git+https://github.com/genouest/biomaj-data.git --no-cache-dir \
    && apt-get install --no-install-recommends -y wget bzip2 ca-certificates curl git nano python3-markupsafe python3-bcrypt python3-yapsy\
    && apt-get purge -y --auto-remove $buildDeps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


RUN pip3 uninstall -y gunicorn && pip3 install --no-cache-dir gunicorn==19.9.0


#Conda installation and give write permissions to conda folder
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    /opt/conda/bin/conda config --add channels r && \
    /opt/conda/bin/conda config --add channels bioconda && \
    /opt/conda/bin/conda upgrade -y conda && \
    chmod 777 -R /opt/conda/


RUN mkdir /data /config

ENV PATH=$PATH:/opt/conda/bin

VOLUME ["/data", "/config"]

RUN mkdir -p /var/lib/biomaj/data

COPY biomaj-config/config.yml /etc/biomaj/config.yml
COPY biomaj-config/global.properties /etc/biomaj/global.properties
COPY biomaj-config/production.ini /etc/biomaj/production.ini
COPY biomaj-config/gunicorn_conf.py /etc/biomaj/gunicorn_conf.py
COPY watcher.sh /root/watcher.sh

# Local test configuration
RUN mkdir -p /etc/biomaj/conf.d && \
    mkdir -p /var/log/biomaj && \
    mkdir -p /etc/biomaj/process.d && \
    mkdir -p /var/cache/biomaj && \
    mkdir -p /var/run/biomaj
COPY test-local/etc/biomaj/global_local.properties /etc/biomaj/global_local.properties
COPY test-local/etc/biomaj/conf.d/alu.properties /etc/biomaj/conf.d/alu.properties

# Plugins
RUN cd /var/lib/biomaj && git clone https://github.com/genouest/biomaj-plugins.git plugins

ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.6.0/wait /wait
RUN chmod +x /wait
COPY startup.sh /startup.sh
