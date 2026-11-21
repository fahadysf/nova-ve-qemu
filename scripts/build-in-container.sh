#!/usr/bin/env bash
# build-in-container.sh — compile + package one QEMU version.
#
# Runs INSIDE the era container (see containers/*.Dockerfile). The container
# toolchain is era-appropriate on purpose: binaries linked against an older
# glibc keep working on newer hosts (forward compatibility), which is what
# lets one Ubuntu 26.04 machine run every version side by side.
#
# Stages the self-contained prefix /opt/nova-ve/qemu/<version> and packs it
# into dist/nova-ve-qemu-<version>_<pkgrev>_amd64.deb.
set -euo pipefail

VERSION="${1:?version required}"
PKGREV="${PKGREV:-1}"
PREFIX="/opt/nova-ve/qemu/${VERSION}"
NPROC="${NPROC:-$(nproc)}"

ROOT="/work"
BUILD="/work/build-${VERSION}"
TARBALL="qemu-${VERSION}.tar.xz"

# ---- 1. verify + extract pinned source ------------------------------------
EXPECTED=$(grep -E "^${VERSION//./\\.} =" /work/versions.ini | head -1 | awk -F' = ' '{print $2}')
if [ -z "${EXPECTED}" ]; then
    echo "FATAL: ${VERSION} not pinned in versions.ini" >&2
    exit 1
fi
ACTUAL=$(sha256sum "${BUILD}/${TARBALL}" | awk '{print $1}')
if [ "${ACTUAL}" != "${EXPECTED}" ]; then
    echo "FATAL: sha256 mismatch for ${TARBALL}" >&2
    echo "  expected ${EXPECTED}" >&2
    echo "  actual   ${ACTUAL}" >&2
    exit 1
fi
echo "==> source verified (${ACTUAL})"

cd "${BUILD}"
rm -rf "qemu-${VERSION}"
tar xf "${TARBALL}"
cd "qemu-${VERSION}"

# ---- 2. apply carried compat patches (quilt-style, if present) -------------
PATCHDIR="/work/patches/${VERSION}"
if [ -d "${PATCHDIR}" ]; then
    for p in "${PATCHDIR}"/*.patch; do
        [ -e "$p" ] || continue
        echo "==> applying $(basename "$p")"
        patch -p1 --batch < "$p"
    done
fi

# ---- 3. configure: minimal headless x86_64 system emulator ----------------
# No GUI stack, no Xen, no extras. Keep: KVM+TCG, virtio/e1000/vmxnet3 NICs,
# qcow2, VNC console, QMP/monitor, serial. Optional features auto-disable
# when their dev libraries are absent in the era container. Only flags that
# exist across every supported version are used here; per-era exceptions
# are appended below.
COMMON_FLAGS=(
    --target-list=x86_64-softmmu
    --prefix="${PREFIX}"
    --disable-werror
    --disable-docs
    --disable-sdl
    --disable-gtk
    --disable-opengl
    --disable-spice
    --disable-smartcard
    --disable-usb-redir
    --disable-xen
    --disable-brlapi
    --disable-curl
    --disable-curses
    --disable-libnfs
    --disable-libiscsi
    --disable-seccomp
)

# --disable-bluez existed only up to the 4.x series; the bluetooth
# subsystem was removed in QEMU 5.2 and the flag is now unknown.
MAJOR="${VERSION%%.*}"
if [ "${MAJOR}" -lt 5 ]; then
    COMMON_FLAGS+=(--disable-bluez)
fi

# Older configure scripts want python2; newer want python3. Pick whatever
# exists in the era container.
if command -v python2 >/dev/null 2>&1; then
    PYTHON_BIN=python2
else
    PYTHON_BIN=python3
fi

echo "==> configure ${VERSION}"
./configure "${COMMON_FLAGS[@]}" --python="${PYTHON_BIN}"

echo "==> make -j${NPROC}"
make -j"${NPROC}"

# ---- 4. stage + strip -------------------------------------------------------
STAGE="${BUILD}/staged"
rm -rf "${STAGE}"
make install DESTDIR="${STAGE}"
find "${STAGE}" -type f -name 'qemu-system-*' -exec strip {} \; 2>/dev/null || true

# ---- 5. pack the deb --------------------------------------------------------
PKG="nova-ve-qemu-${VERSION}"
DEBDIR="${BUILD}/deb/${PKG}"
rm -rf "${DEBDIR}"
mkdir -p "${DEBDIR}/DEBIAN" "${DEBDIR}$(dirname "${PREFIX}")"
cp -a "${STAGE}${PREFIX}" "${DEBDIR}${PREFIX}"

cat > "${DEBDIR}/DEBIAN/control" <<EOF
Package: ${PKG}
Version: ${PKGREV}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: nova-ve <info@nova-ve.com>
Description: QEMU ${VERSION} (headless x86_64 system emulation) for nova-ve
 Self-contained QEMU ${VERSION} build installed under ${PREFIX}.
 Built from the upstream qemu-${VERSION} release tarball with a minimal
 headless configuration (no GUI/X dependencies). Runs alongside other
 nova-ve-qemu-* packages and the distribution QEMU without conflicts.
Installed-Size: $(du -sk "${DEBDIR}${PREFIX}" | awk '{print $1}')
EOF

mkdir -p "${ROOT}/dist"
dpkg-deb --root-owner-group --build "${DEBDIR}" "${ROOT}/dist/${PKG}_${PKGREV}_amd64.deb"

echo "==> built ${ROOT}/dist/${PKG}_${PKGREV}_amd64.deb"
