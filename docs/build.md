# How the images are built

Details behind the short build description in the root [`README.md`](../README.md).

## Payloads

The payloads are **not versioned**. They sit in the working tree next to the
Containerfiles — `SynopsysInstaller_v5.10.run`, `ValidationTool`, every
`*.spf` / `*.spf.partNN` volume — and the root `.gitignore` keeps them out of
git, so a clone is text-only. Supply them from the vendor delivery before
building.

Every build context has a `flist` next to its Containerfile. It lists the
versioned sources and the untracked vendor payloads that must be present in
that directory for the build, and calls out files that are present but not
used (merged ESTs, other platforms, docs). Stage a delivery against it; CI
treats `flist` changes as documentation, not as a rebuild trigger. The
payload-only `vcs/2024.09-SP1/` has a `flist` but no Containerfile, because
that delivery is kept for reference/rollback and is not built.

Both the CI and a local build use the checkout as the build context; the CI
runs exactly this, with the product directory as `--local context=`:

```sh
buildctl --addr tcp://buildkitd.buildkit.svc.cluster.local:1234 build \
  --frontend dockerfile.v0 \
  --local context=/data2/synopsys/dc/2025.06-SP4 --local dockerfile=/data2/synopsys/dc/2025.06-SP4 \
  --opt filename=Containerfile --opt build-arg:EDABASE=... \
  --output type=image,name=local.io/synopsys/dc:2025.06-SP4,push=true
```

The CI job pods mount the cluster's `/data2` (GPFS) and build from the same
directory, so nothing is copied or uploaded between the checkout and BuildKit
beyond the context stream itself. That stream is not covered by the registry
cache: `buildctl --local context=` sends the product directory to the daemon
before the first step is scheduled, so every build pays for the payload size
(`fm` ~0.9 GB, `spyglass` ~1.2 GB, `lc` ~1.5 GB, `vcs` ~4.7 GB, `verdi` ~11.6 GB,
`fc` ~12.5 GB, `pt` ~6.4 GB, `dc` ~17 GB, `vcst` ~30 GB; `synopsys/` only
stages the 3 MB KasmVNC RPM, because its tool trees come out of the registry).
A daemon that still has the previous local-source snapshot only transfers
changed files, but that does not survive a buildkitd restart or cache GC.

Two consequences:

- the payload bytes are not archived anywhere, and a lost payload set cannot be
  recovered from this repository, so keep the vendor delivery for as long as
  the images built from it are in use. The image digest already pins the inputs
  (BuildKit hashes the payloads into the install `RUN`'s cache key), which is
  why the old `org.synopsys.payloads` label was dropped: it cost a full extra
  30 GB read per build to record what the digest already proves;
- `/data2` is cluster-wide, so every job pod can read (and write) it.

Payloads that are present but never built:

| Path | Why |
| --- | --- |
| merged `*.spf` produced from `.partNN` volumes (`dc/`, `fc/`, `pt/`, `vcs/`, `verdi/`, `vcst/`) | `joinEst.sh` rebuilds them inside the build; `.dockerignore` keeps them out of the build context |
| `vcs/2024.09-SP1/` | the VCS delivery between the two built releases, kept for reference/rollback; only the `2025.06-SP1` and `2023.12-SP2` contexts are built |
| `vip/2023.12/vip_*.run` except `vip_library19_svt`, `vip_ecpri_svt`, `vip_memory_svt` | the three selected packages hold the complete compile-time tree for `vip/`, and `synopsys/` copies exactly that tree out of the `vip` image, see [`vip/2023.12/README.md`](../vip/2023.12/README.md) |
| `ciel/archives/<family>-<version>/` | downloaded CIEL releases; unpacked to `ciel/pdk/` (pristine image) and `ciel/pdk-dc/` (plus DC `.db` views), see [`ciel/README.md`](../ciel/README.md) |
| `ASAP7/asap7/` | upstream ASAP7 checkout (superproject + five submodules, ~19 GB) mirrored into the host-mounted PDK store as `pdk/asap7/`, see [`ASAP7/README.md`](../ASAP7/README.md) |
| `ASAP7/asap7_snps/` | ASAP7 Synopsys supplement (~1 MB, ICC tech file and StarRC ITF), mirrored to `pdk/asap7/asap7_snps/` |

Alternate-platform packages, offline docs and the optional SpyGlass-VCS UFE
tree are not kept: each build directory contains only the files in its
`flist`.

## EST volumes (`*.spf.partNN`)

Large platform images are delivered as `*.spf.part00`, `.part01`, ... volumes.
Each volume carries a text header: EST name, volume count, index, the size and
CRC32/MD5 of the joined file, then a per-volume header token, CRC32, MD5 and
payload length. They are **not** a plain `split`, so `cat` corrupts the image.

Nothing special is needed in the Containerfiles: `batch_installer` runs the
Installer's own `joinEst.sh`, which verifies every volume MD5 and the joined
file MD5 before writing the `.spf`, then extracts it. Copy the `.partNN`
volumes as delivered and the installer rebuilds the `.spf` in place.

## Layering

`vcs/`, `verdi/`, `lc/`, `spyglass/`, `dc/`, `fc/`, `fm/`, `pt/` and `vcst/`
are built on the two `base/` images instead of repeating the AlmaLinux mirror
fixup, the dnf package lists, the Installer extraction and the ValidationTool
integrity check (`synopsys/` starts from the runtime base and installs only its
runtime packages, because its tool trees come from those images):

| Stage   | Image                 | Provides                                                        |
| ------- | --------------------- | --------------------------------------------------------------- |
| `build` | `local.io/synopsys/build:8.10`   | `batch_installer` in `/opt/synopsys-installer`, `ValidationTool` (validates the integrity of the Synopsys EDA tools), `SI_ACCEPT_LICENSE=1`, perl/gcc toolchain, `bash` and `tcsh` |
| runtime | `local.io/synopsys/runtime:8.10` | X11/GL/libstdc++/FlexLM libraries, `numactl-libs`, `LANG=en_US.UTF-8` |

No image sets a license server address: Jobs pass `SNPSLMD_LICENSE_FILE` and
`LM_LICENSE_FILE` in their `env` (`2700@license` inside `synopsys`), and
`nerdctl run` callers pass `-e`.

`bash` is the interpreter `joinEst.sh` asks for, and `tcsh` is what the
`admin/install/*/bin/install_*` post-install hooks of `dc`, `fm` and `pt`
declare (`#!/bin/csh -f`). Both are install-time needs shared by every product,
so they live in the build stage rather than in individual Containerfiles.

Product Containerfiles take an `EDABASE` arg (default `local.io/synopsys`) for
the registry prefix, so the bases can be pulled from a different endpoint.

`vip/` is the exception in the other direction: only its build stage uses the
`build` image (for `perl`/`tar` and `ValidationTool`), and the tree is copied
to `scratch` because the result is a read-only file volume rather than a
runtime image. See [`vip/2023.12/README.md`](../vip/2023.12/README.md).

### `synopsys`: every tool in one module-managed image

`synopsys/2025.06/` is the union of the product images plus the open PDK trees
and a KasmVNC desktop, assembled without installing anything: every tool tree is
`COPY --from` the image that already installed and patched it
(`vcs/2025.06-SP1/`, `verdi/2025.06-SP1/`, ...), VIP comes from the 3-package
`vip/2023.12/` image, `/opt/pdk` from `ciel-pdk-dc` and its `pristine/`
subdirectory from `ciel-pdk`. The per-tool environments are kept apart with
modulefiles under `/opt/modulefiles` instead of one global `PATH`/`LD_PRELOAD`,
and the `CMD` starts KasmVNC + XFCE. See
[`synopsys/2025.06/README.md`](../synopsys/2025.06/README.md).

## Start probe

Every tool image carries its own start probe and runs it as the final build
step (`COPY smoke.sh /opt/eda-smoke/smoke.sh` then `RUN ... smoke.sh` in that
tool's Containerfile), so an image whose tool cannot start fails the build
before it is pushed and the `synopsys` assembly never consumes it. The probe
lives next to the tool (`dc/2025.06-SP4/smoke.sh`, `fc/2025.06/smoke.sh`, ...)
and drives the tool's own Tcl shell with a short script that prints
`EDA_SMOKE_OK` and exits. Reaching it proves the wrapper, the bundled libraries
and the license checkout all worked, which is exactly where the image-specific
fixes live (libudev preload, bundled crypto removal, Qt/xcb packages).

| Image | Start probe |
| --- | --- |
| `dc`, `fc`, `pt`, `fm`, `lc` | `<tool>_shell -f smoke.tcl` |
| `spyglass` | `sg_shell -tcl smoke.tcl` |
| `vcst` | `vc_static_shell -f smoke.tcl` |
| `vcs` | `vcs -full64 -ID` |
| `verdi` | `verdi -id` |
| `scl` | no probe (license server image, not a tool) |

The probe uses the cluster license service
(`SNPSLMD_LICENSE_FILE=2700@license.synopsys.svc.cluster.local`), so a build
needs it. The probe `RUN` mounts `/tmp` and `/root` as tmpfs: the tools keep
their command logs and license cache there and none of that belongs in an image
layer. `lc_shell X-2025.06` segfaults while exiting after the script; its probe
accepts that specific exit status only once the marker was printed. Re-run a
probe against a finished image with
`nerdctl run --rm --entrypoint /opt/eda-smoke/smoke.sh <image>`. The assembled
`synopsys` image is checked by `synopsys/2025.06/k8s/synopsys-smoke.yaml`, not
by these probes.

To check that a build reached the registry:

```sh
curl -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
     http://10.196.10.52:32767/v2/synopsys/vcs/tags/list
```
