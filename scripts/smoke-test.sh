#!/usr/bin/env bash
# smoke-test.sh — install a freshly built deb in a clean ubuntu:26.04
# container and prove the binary works on the deployment OS generation.
#
# Usage: smoke-test.sh <path/to/deb> <qemu-version>
set -euo pipefail

DEB="$(cd "$(dirname "${1:?deb path required}")" && pwd)/$(basename "${1}")"
VERSION="${2:?version required}"
BIN="/opt/nova-ve/qemu/${VERSION}/bin/qemu-system-x86_64"

echo "==> smoke testing $(basename "${DEB}") in ubuntu:26.04"
docker run --rm \
    --platform linux/amd64 \
    -v "$(dirname "${DEB}"):/debs:ro" \
    ubuntu:26.04 \
    bash -euo pipefail -c "
        apt-get update -qq
        # apt (not dpkg -i) so the declared Depends resolve (libglib/libpixman).
        apt-get install -y -qq /debs/$(basename "${DEB}") >/dev/null
        echo '--- version:'
        ${BIN} --version
        echo '--- version string matches ${VERSION}:'
        ${BIN} --version | head -1 | grep -F 'version ${VERSION}'
        # 2.x-era QEMU prints `*-help` listings to stderr and exits nonzero,
        # so every probe merges streams and tolerates the exit status.
        echo '--- machine pc available:'
        { ${BIN} -machine help 2>&1 || true; } | grep -E '^pc([[:space:]]|\$)' | head -2
        echo '--- required NIC models available:'
        { ${BIN} -device help 2>&1 || true; } | grep -cE 'name \"(virtio-net-pci|e1000|vmxnet3)\"'
        test \"\$( { ${BIN} -device help 2>&1 || true; } | grep -cE 'name \"(virtio-net-pci|e1000|vmxnet3)\"' )\" -ge 3
        echo '--- KVM accel available in build:'
        { ${BIN} -accel help 2>&1 || true; } | grep -q kvm || { ${BIN} -machine accel=help 2>&1 || true; } | grep -q kvm
        echo 'SMOKE OK'
    "
echo "==> smoke test passed"
