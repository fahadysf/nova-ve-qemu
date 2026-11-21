# Era container for mid-tier QEMU: 3.x–7.x.
# ubuntu:20.04 (GCC 9, glib 2.64, python3.8, meson/ninja available for the
# versions that grew into the meson build system).
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        python3 \
        python3-pip \
        meson \
        ninja-build \
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
