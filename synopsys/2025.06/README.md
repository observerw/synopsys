# Synopsys EDA suite (all tools, modules, KasmVNC, open PDKs)

One image with every Synopsys product tree this repository ships, the open
PDKs, an XFCE desktop and a KasmVNC web remote desktop:

| Component | Version | Module | Entry point |
| --- | --- | --- | --- |
| VCS | X-2025.06-SP1 | `vcs` | `vcs` |
| Verdi | X-2025.06-SP1 (+ `verdi_supp`) | `verdi` | `verdi` |
| Design Compiler (`syn`) | X-2025.06-SP4 | `dc` | `dc_shell` |
| Fusion Compiler | X-2025.06 | `fc` | `fc_shell` |
| PrimeTime (`prime`) | X-2025.06 | `pt` | `pt_shell` |
| Formality (`fm`) | X-2025.06 | `fm` | `fm_shell` |
| Library Compiler | X-2025.06 | `lc` | `lc_shell` |
| SpyGlass | X-2025.06 | `spyglass` | `spyglass`, `sg_shell` |
| VC Static / VC Formal | X-2025.06-SP2 | `vcst` | `vc_static_shell`, `vcf` |
| VIP | V-2023.12 (`library19`, `ecpri`, `memory`) | — (image `ENV`) | `DESIGNWARE_HOME`, `bin` on `PATH` |
| Open PDKs | 2026.11 | — (image `ENV`) | `PDK_ROOT=/opt/pdk` (DC views); pristine in `/opt/pdk/pristine` |

```
local.io/synopsys/synopsys:2025.06
```

The image contains no license server, no daemon and no license file. Set
`SNPSLMD_LICENSE_FILE=2700@license` and `LM_LICENSE_FILE=2700@license` in the
Pod `env` (or pass `-e` to `nerdctl`).

This image is assembled from the single-product images (`vcs/`, `verdi/`,
`dc/`, `fc/`, `pt/`, `fm/`, `lc/`, `spyglass/`, `vcst/`), the 3-package `vip/`
image, the XFCE/KasmVNC desktop and the PDK images.  Every tree is copied
out of the image that already installed and patched it, so this build does not
run an installer.  It does not include the SCL license server (`scl/`), the
open-source LibreLane image, or ASAP7 (mount `pdk/asap7-dc` at `/pdks` when a
flow needs it).

## Why modules

The tools do not share one environment:

* Fusion Compiler, PrimeTime, Formality and Library Compiler need
  `LD_PRELOAD=/lib64/libudev.so.1` for the FlexLM hostid enumeration; SpyGlass
  needs the same preload, but through `SPYGLASS_LD_PRELOAD`, because its
  wrapper replaces `LD_PRELOAD` before it starts the checker;
* VC Static/VC Formal need their bundled Qt/xcb directories ahead of the
  system libraries in `LD_LIBRARY_PATH`;
* every product wants its own `*_HOME` and `PATH` entry.

Putting all of that into the image `ENV` recreates the conflicts the
single-product images avoid. Instead the image ships modulefiles under
`/opt/modulefiles` and loads nothing by default. The `module` function itself
comes from environment-modules' own `/etc/profile.d` hooks, so this repository
ships no wrapper. Module names have no `eda/` prefix:

```sh
eda-shell dc                   # bash with Design Compiler loaded
module load vcs verdi          # compile and debug in one shell
module load pt                 # only PT's PATH and LD_PRELOAD
module avail
module list
module purge
```

Two things are the exception, because they add no `LD_*` setting and no
executable tool to choose between: the PDK (only the variant name next to the
root) and VIP (a compile-time tree whose `bin/` holds the `dwh_install` setup
helpers).  `PDK_ROOT`, `PDK`, `DESIGNWARE_HOME` and `PATH` are therefore plain
image `ENV` and are set in every shell, modules loaded or not.  Switching PDK
variant or root is just an assignment, and `module purge` does not touch it:

```sh
PDK=gf180mcuD bash -lc 'echo "$PDK_ROOT/$PDK"'                # another variant
PDK_ROOT=/opt/pdk/pristine bash -lc 'echo "$PDK_ROOT/$PDK"'   # pristine tree
```

## Layout

```
synopsys/2025.06/
  Containerfile            assembly: COPY --from the product/vip/ciel images
  fetch-kasmvnc.sh         fetches the official KasmVNC RPM into kasmvnc/
  modulefiles/<tool>/...   one modulefile (and default .version) per tool
  motd                     the Chinese quick-start banner printed on login
  scripts/motd.sh          prints /etc/motd for interactive shells only
  kasmvnc/kasmvnc.yaml     overrides only (per-user TLS PEM, IPv4-only)
  kasmvnc/*.rpm            the downloaded KasmVNC RPM (gitignored)
  scripts/eda-vnc          CMD: foreground KasmVNC + XFCE
  scripts/xstartup         XFCE session; loads EDA_MODULES
  scripts/eda-shell        interactive shell with modules loaded
  k8s/synopsys-vnc.yaml    Pod + Service exposing KasmVNC on 6901
  k8s/synopsys-smoke.yaml  Job: trees, modules, PDK and version probes
```

## Fetch the KasmVNC RPM

The tool trees, VIP and the open PDKs are copied out of the registry, so the
only file this build context needs from the host is the KasmVNC RPM (the build
pods have no GitHub egress):

```sh
cd /data2/synopsys/synopsys/2025.06
./fetch-kasmvnc.sh
```

It downloads `kasmvncserver_oracle_8_1.5.2_x86_64.rpm` from
<https://github.com/kasmtech/KasmVNC/releases/tag/v1.5.2> into `kasmvnc/`,
verified against
`sha256:8f37a5e75c09420228108e665f6e40e90d83ee767c1874c4c9eee04fcc853df2`.
If the host has no GitHub egress, place that RPM in `kasmvnc/` manually; the
script then only verifies it.

## Build

CI builds this image after `tools`, `vip` and `ciel`; it copies the installed
trees out of `local.io/synopsys/vcs:2025.06-SP1`, `.../verdi:2025.06-SP1`,
`.../dc:2025.06-SP4`, `.../fc:2025.06`, `.../pt:2025.06`, `.../fm:2025.06`,
`.../lc:2025.06`, `.../spyglass:2025.06`, `.../vcst:2025.06-SP2`,
`.../vip:2023.12`, `.../ciel-pdk:2026.11` and `.../ciel-pdk-dc:2026.11`, so
those images must be in the registry (a product whose sources did not change
keeps its existing image).
The KasmVNC RPM is mounted into the desktop `RUN` and installed with
`dnf localinstall`, following the official RHEL 8-compatible steps.

Expected size: roughly 210-260 GB unpacked (VCS+Verdi+VIP ~50 GB, VC
Static/VC Formal ~89 GB, DC ~20 GB, FC ~13 GB, PT ~7 GB, LC ~1.5 GB, SpyGlass
~1.2 GB, PDK ~22 GB twice, desktop ~2 GB). Re-copying and exporting those trees
is what dominates the build time; the PDK tree is the only one copied twice
(pristine and DC-ready), and the CI uses zstd layers.

`EDABASE` selects the registry prefix for every source image and the runtime
base; the default is `local.io/synopsys`.

## Run the KasmVNC desktop

The image's `CMD` is `/usr/local/bin/eda-vnc`. It starts KasmVNC in the
foreground (`-fg`) on display `:1`, serving the web client over HTTPS on port
6901, and runs XFCE inside it:

```sh
sudo nerdctl run -it --rm -p 6901:6901 \
  -e SNPSLMD_LICENSE_FILE=2700@license \
  -e LM_LICENSE_FILE=2700@license \
  -e VNC_PASSWORD=kasmvnc \
  -e VNC_GEOMETRY=1920x1080 \
  local.io/synopsys/synopsys:2025.06
```

Open <https://localhost:6901/> and log in with `VNC_USER` and
`VNC_PASSWORD` (defaults `kasm_user` / `kasmvnc`). `eda-vnc` generates a
self-signed certificate on first start, so the browser shows a certificate
warning. The XFCE terminals inherit the environment and load `EDA_MODULES`
(empty by default); `module load dc` is then enough to start a tool.  Set
`EDA_MODULES="vcs verdi"` to preload a set.  `PDK`/`PDK_ROOT` are image `ENV`,
so no module is involved.

| Variable | Default | Meaning |
| --- | --- | --- |
| `VNC_DISPLAY` | `:1` | X display number |
| `VNC_WEBSOCKET_PORT` | `6901` | HTTPS web/websocket port |
| `VNC_GEOMETRY` | `1920x1080` | desktop size |
| `VNC_DEPTH` | `24` | colour depth |
| `VNC_USER` | `kasm_user` | KasmVNC HTTP Basic user |
| `VNC_PASSWORD` | `kasmvnc` | password (KasmVNC requires at least 6 characters) |
| `EDA_MODULES` | (empty) | modules loaded in the X session |

KasmVNC speaks its own web protocol; the legacy RFB VNC port is not exposed.
Use the browser client at the printed `https://host:6901/` URL.

For a Job or a one-off tool run, replace the CMD:

```sh
# a shell with no tool loaded
sudo nerdctl run -it --rm local.io/synopsys/synopsys:2025.06 bash

# a single tool, environment scoped by its module
sudo nerdctl run -it --rm local.io/synopsys/synopsys:2025.06 \
  bash -lc 'module load dc; dc_shell -f run.tcl'
```

The image has no `ENTRYPOINT`, so a command passed after the image name
replaces `eda-vnc`.

### Kubernetes

```sh
kubectl -n synopsys apply -f synopsys/2025.06/k8s/synopsys-vnc.yaml
kubectl -n synopsys port-forward svc/synopsys-vnc 6901:6901
```

Then open <https://127.0.0.1:6901/>. The Pod mounts the shared `/data2` at
`/data2` and sets `/work` as the working directory; change `VNC_USER` and
`VNC_PASSWORD` in the manifest before exposing the Service.

## PDKs

Two trees of the same open-PDK release are baked in:

| Path | Contents | Used by |
| --- | --- | --- |
| `/opt/pdk` | the PDK root plus the typical-corner Design Compiler `.db` views | `PDK_ROOT`/`PDK` in the image `ENV` |
| `/opt/pdk/pristine` | the pristine tree, no `.db` views | flows that need the upstream tree untouched: `PDK_ROOT=/opt/pdk/pristine` |

Both are complete PDK roots, so either can be used by pointing `PDK_ROOT` at
it; the variants are the same in both.  The variant symlinks (`sky130A`,
`gf180mcuD`, `ihp-sg13g2`, `freepdk45`, ...) are relative and resolve in place:

```tcl
# Design Compiler / PrimeTime / Formality
set target_library [glob /opt/pdk/sky130A/libs.ref/*/db/*tt_025C_1v80*.db]
set link_library   "* $target_library"
```

The pristine tree has no `.db` views, so run Liberty compilation first when a
flow there needs them.

ASAP7 is not packaged into this image.  Mount the dc-ready `pdk/asap7-dc` tree
from the host at `/pdks` when a flow needs it (see
[`../../ASAP7/README.md`](../../ASAP7/README.md)):

```tcl
# Design Compiler / PrimeTime / Formality
set target_library [glob /pdks/asap7sc7p5t_28/LIB/db/*_RVT_TT_*.db]
set link_library   "* $target_library"
```

The PDK trees are baked into the image; mounting a newer PDK root at `/pdks`
and setting `PDK_ROOT` is still possible when a flow needs a different release.
The image ships the Synopsys tools only; the open-source LibreLane flow keeps
its own image and can mount the same tree.

## Environment in the image

```sh
SYNOPSYS=/opt/synopsys
DESIGNWARE_HOME=/opt/designware
PDK_ROOT=/opt/pdk
PDK=sky130A
PATH=/opt/designware/bin:$PATH      # the VIP setup helpers only
MODULEPATH=/opt/modulefiles
```

`PATH` has no product tool bin directory and `LD_PRELOAD`/`LD_LIBRARY_PATH`
carry no tool settings until a module is loaded. Each module sets only what its
tool needs:

| Module | Sets |
| --- | --- |
| `vcs` | `VCS_HOME`, `PATH` |
| `verdi` | `VERDI_HOME`, `PATH` |
| `dc` | `PATH` |
| `fc`, `pt`, `fm` | `PATH`, `LD_PRELOAD=/lib64/libudev.so.1` |
| `lc` | `LC_HOME`, `LC_STARTUP_CHECKOUT_LIC=1`, `PATH`, `LD_PRELOAD` |
| `spyglass` | `SPYGLASS_HOME`, `SPYGLASS_LD_PRELOAD=/lib64/libudev.so.1`, `PATH` |
| `vcst` | `VC_STATIC_HOME`, `PATH`, bundled Qt/xcb `LD_LIBRARY_PATH` |

There are no `pdk` and `vip` modules: neither has a shell entry point of its
own, and neither needs an `LD_*` setting, so `PDK_ROOT`/`PDK` and
`DESIGNWARE_HOME`/`PATH` stay image `ENV` and are there in every shell.

## Runtime fixes carried over from the single-product images

All of these are applied by the individual product images; this image inherits
them by copying their installed trees. They are listed here because they are
what makes the copied trees runnable in this image too.

* **Verdi**: `verdi_supp` is integrated by hand (move under `platform/`, link
  `platform/linux64/lib/vcs`) because its hook calls `vcs -id`; the Qt5 xcb
  system libraries are installed.
* **PrimeTime/Formality**: bundled el7 `libk5crypto.so.3` removed; libudev
  preloaded by the module.
* **Fusion Compiler**: bundled `libk5crypto.so.3` and the two
  `libcrypto.so.1.1` copies removed; libudev preloaded by the module.
* **Library Compiler**: bundled `libk5crypto.so.3` and `libcrypto.so.1.1*`
  removed, offline docs removed, `LC_STARTUP_CHECKOUT_LIC=1` set by the module.
* **SpyGlass**: the libudev preload is exported as `SPYGLASS_LD_PRELOAD` by the
  module; the image `ENV` cannot carry it, and a plain `LD_PRELOAD` is
  discarded by the wrapper.
* **VC Formal**: the `impl` overlay is installed with `vc_static`; the bundled
  Qt/xcb path is scoped to the `vcst` module.
* **VCS**: gcc/g++, make, binutils, glibc-devel, bc and time are in the image
  for DPI/UVM compilation, `dc` (RecordTime) and `/usr/bin/time`.
* **KasmVNC**: installed from the official Oracle 8 RPM for RHEL 8-compatible
  hosts (powertools + EPEL enabled); `/etc/kasmvnc/kasmvnc.yaml` only overrides
  the per-user TLS PEM and IPv4-only listening, the rest comes from the RPM's
  default config (which enforces TLS). `eda-vnc` starts it and supplies the
  per-run geometry/depth/port. `kasmvncpasswd` manages the `~/.kasmpasswd`
  HTTP Basic file and `eda-vnc` generates `~/.vnc/self.pem` on first start.
  The desktop runs as the container user; mount a writable `HOME` when running
  with an arbitrary UID.
