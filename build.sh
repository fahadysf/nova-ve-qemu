#!/usr/bin/env bash
# build.sh — build one nova-ve-qemu deb for <version> using its era container.
#
# Usage: build.sh <qemu-version> <container-tier>
#   e.g. build.sh 2.12.1 legacy-2.12
#
# Runs ON THE RUNNER (needs docker + dpkg-deb). The heavy compile happens in
# the era container (scripts/build-in-container.sh); packaging happens in the
# same container so the deb metadata matches the build environment.
set -euo pipefail

VERSION="${1:?usage: build.sh <version> <container-tier>}"
TIER="${2:?usage: build.sh <version> <container-tier>}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="nova-ve-qemu/${TIER}:${VERSION}"

echo "==> building nova-ve-qemu-${VERSION} (tier: ${TIER})"
docker build --pull -f "${ROOT}/containers/${TIER}.Dockerfile" -t "${IMAGE}" "${ROOT}/containers"

rm -rf "${ROOT}/build-${VERSION}" "${ROOT}/dist"
mkdir -p "${ROOT}/build-${VERSION}" "${ROOT}/dist"

# Cache the pinned source tarball on the runner (once); the container
# verifies its sha256 against versions.ini before building.
TARBALL="qemu-${VERSION}.tar.xz"
if [ ! -f "${ROOT}/build-${VERSION}/${TARBALL}" ]; then
    curl -sSL -o "${ROOT}/build-${VERSION}/${TARBALL}" "https://download.qemu.org/${TARBALL}"
fi

docker run --rm \
    -v "${ROOT}:/work" \
    -w /work \
    "${IMAGE}" \
    bash "scripts/build-in-container.sh" "${VERSION}"

# The container wrote dist/*.deb as root; hand it back to the runner user.
sudo chown -R "$(id -u):$(id -g)" "${ROOT}/dist" 2>/dev/null || true

echo "==> artifacts:"
ls -la "${ROOT}/dist"
