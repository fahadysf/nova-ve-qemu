# Era container for current QEMU: 8.x+.
# ubuntu:24.04 (GCC 13, glib 2.80, python3.12, meson 1.3, ninja).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        python3 \
        python3-venv \
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
