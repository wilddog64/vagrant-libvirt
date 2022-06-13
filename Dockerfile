# syntax = docker/dockerfile:1.0-experimental
ARG VAGRANT_VERSION=2.2.19


FROM ubuntu:bionic as base

RUN apt update \
    && apt install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        gosu \
        kmod \
        libvirt-bin \
        openssh-client \
        qemu-utils \
        rsync \
    && rm -rf /var/lib/apt/lists \
    && mkdir /vagrant

ENV VAGRANT_HOME /vagrant

ARG VAGRANT_VERSION
ENV VAGRANT_VERSION ${VAGRANT_VERSION}
RUN set -e \
    && curl https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.deb -o vagrant.deb \
    && apt update \
    && apt install -y ./vagrant.deb \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f vagrant.deb \
    ;

FROM base as build

# allow caching of packages for build
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache \
   && sed -i '/deb-src/s/^# //' /etc/apt/sources.list

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
    apt update \
    && apt build-dep -y \
        vagrant \
        ruby-libvirt \
    && apt install -y --no-install-recommends \
        libxslt-dev \
        libxml2-dev \
        libvirt-dev \
        ruby-bundler \
        ruby-dev \
        zlib1g-dev \
    ;

WORKDIR /build

COPY . .
# RUN rake build
# RUN vagrant plugin install ./pkg/vagrant-libvirt*.gem
RUN vagrant plugin vagrant-libvirt && vagrant plugin list

RUN for dir in boxes data tmp; \
    do \
        touch /vagrant/${dir}/.remove; \
    done \
    ;

FROM base as slim

COPY --from=build /vagrant /vagrant

COPY entrypoint.sh /usr/local/bin/

FROM build as final

ENV VAGRANT_DEFAULT_PROVIDER=libvirt
RUN useradd -s /bin/bash vagrant -g users -G adm && \
    mkdir -p /home/vagrant && \
    vagrant plugin install vagrant-libvirt && \
    vagrant plugin list && \
    mv /usr/bin/ruby /usr/bin/ruby.old

COPY entrypoint.sh /usr/local/bin/

ENTRYPOINT ["entrypoint.sh"]
# CMD /bin/bash
# vim: set expandtab sw=4:
