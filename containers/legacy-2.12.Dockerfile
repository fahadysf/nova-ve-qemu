# Era container for the legacy floor: QEMU 2.12.x.
# ubuntu:18.04 (GCC 7, glib 2.56, python2) — the toolchain generation 2.12
# was built against. Binaries linked here run on newer hosts via glibc
# forward compatibility.
FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN printf 'deb http://archive.ubuntu.com/ubuntu bionic main\ndeb http://archive.ubuntu.com/ubuntu bionic universe\n' > /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        python \
        libglib2.0-dev \
        libpixman-1-dev \
        zlib1g-dev \
        flex \
        bison \
        perl \
        wget \
        ca-certificates \
        file \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
