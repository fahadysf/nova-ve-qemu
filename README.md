# nova-ve-qemu

Side-by-side QEMU builds for [nova-ve](https://github.com/fahadysf/nova-ve),
packaged as Debian debs and published on GitHub Releases.

Vendor network-OS images are certified against specific QEMU generations —
machine-type defaults, NIC model sets, and PCI topology shift between
releases, so an image that boots on one QEMU can come up NIC-less or hang on
the next. This repo builds multiple QEMU versions with a minimal headless
configuration and installs each into its own self-contained prefix:

```
/opt/nova-ve/qemu/<version>/
├── bin/qemu-system-x86_64
└── share/qemu/          # ROM blobs, keymaps
```

Every version coexists with the others and with the distribution QEMU; nova-ve
selects the emulator per template / per node.

## Supported versions (2.12 floor)

| Version | Tier | Build container |
|---|---|---|
| 2.12.1 | legacy floor | `ubuntu:18.04` |
| 4.1.0 | mid | `ubuntu:20.04` |
| 5.2.0 | mid | `ubuntu:20.04` |
| 11.1.3 | current | `ubuntu:24.04` |

New versions enter the menu only when a template in the wild demonstrably
pins them. Nothing older than 2.12 will be built.

## Methodology

- **Pinned sources**: every version is pinned by sha256 in
  [`versions.ini`](versions.ini); the build aborts on any mismatch.
- **Era-appropriate toolchains**: each tier compiles inside a container whose
  compiler/glibc generation matches the release era. Binaries linked against
  an older glibc run on newer hosts (forward compatibility) — that is why
  these debs work on Ubuntu 26.04 regardless of build era.
- **Minimal headless build**: `--target-list=x86_64-softmmu`, no GUI/X
  dependencies, KVM + TCG, virtio/e1000/vmxnet3 NICs, qcow2, VNC, QMP,
  serial console. Optional features auto-disable in the lean containers.
- **Carried patches**: any source patch we must carry lives in
  `patches/<version>/*.patch` and is applied by CI — nothing is patched
  out-of-band.
- **Smoke-tested per build**: each deb is installed in a clean
  `ubuntu:26.04` container and must report its exact version, expose the
  `pc` machine, the virtio-net-pci/e1000/vmxnet3 NIC models, and KVM
  acceleration before it can ship.

## Building

CI (GitHub Actions) runs the version matrix on self-hosted runners labelled
`self-hosted, qemu-build` — every version builds in parallel. Locally the
same result:

```bash
bash build.sh 2.12.1 legacy-2.12
bash scripts/smoke-test.sh dist/nova-ve-qemu-2.12.1_1_amd64.deb 2.12.1
```

Releases are tagged `v*`; the workflow attaches every deb plus a
`SHA256SUMS` file to the GitHub Release.

## Installing on a nova-ve host

```bash
# from a release page:
curl -fLO https://github.com/fahadysf/nova-ve-qemu/releases/download/<tag>/nova-ve-qemu-5.2.0_1_amd64.deb
sudo apt-get install ./nova-ve-qemu-5.2.0_1_amd64.deb
/opt/nova-ve/qemu/5.2.0/bin/qemu-system-x86_64 --version
```

nova-ve's `install.sh` can do this automatically for the recommended set —
see the nova-ve repo.

## License / source offering

QEMU is GPLv2. The debs distributed here are built from the pinned upstream
tarballs listed in `versions.ini` plus (if any) the patches carried in this
repository; the repository content at the release tag **is** the complete,
corresponding build recipe and source-offering for those binaries.
