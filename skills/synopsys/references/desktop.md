# Desktop image

`local.io/synopsys/synopsys:2025.06` contains every Synopsys tool tree in this
repository, the VIP tree, the open PDKs, XFCE and KasmVNC. The tools are kept
apart with modulefiles under `/opt/modulefiles`; nothing is loaded by default.

| Component | Version | Module | Entry point |
| --- | --- | --- | --- |
| VCS | X-2025.06-SP1 | `vcs` | `vcs` |
| Verdi | X-2025.06-SP1 | `verdi` | `verdi` |
| Design Compiler | X-2025.06-SP4 | `dc` | `dc_shell` |
| Fusion Compiler | X-2025.06 | `fc` | `fc_shell` |
| PrimeTime | X-2025.06 | `pt` | `pt_shell` |
| Formality | X-2025.06 | `fm` | `fm_shell` |
| Library Compiler | X-2025.06 | `lc` | `lc_shell` |
| SpyGlass | X-2025.06 | `spyglass` | `spyglass`, `sg_shell` |
| VC Static / VC Formal | X-2025.06-SP2 | `vcst` | `vc_static_shell`, `vcf` |
| VIP | V-2023.12 | — | `DESIGNWARE_HOME`, `bin` on `PATH` |
| Open PDKs | 2026.11 | — | `PDK_ROOT=/opt/pdk` |

```sh
eda-shell dc                   # bash with Design Compiler loaded
module load vcs verdi          # several tools in one shell
module avail
module list
module purge
```

`PDK_ROOT`, `PDK`, `DESIGNWARE_HOME` and `PATH` are plain image `ENV`, so they
are set in every shell, modules loaded or not. Switch PDK variant or root with
an assignment:

```sh
PDK=gf180mcuD bash -lc 'echo "$PDK_ROOT/$PDK"'
PDK_ROOT=/opt/pdk/pristine bash -lc 'echo "$PDK_ROOT/$PDK"'
```

## Run with nerdctl

```sh
nerdctl run -it --rm -p 6901:6901 \
  -e SNPSLMD_LICENSE_FILE=2700@license \
  -e LM_LICENSE_FILE=2700@license \
  -e VNC_PASSWORD=kasmvnc \
  -e VNC_GEOMETRY=1920x1080 \
  local.io/synopsys/synopsys:2025.06
```

Open <https://localhost:6901/> and log in with `VNC_USER` and `VNC_PASSWORD`
(defaults `kasm_user` / `kasmvnc`). KasmVNC generates a self-signed certificate
on first start.

| Variable | Default | Meaning |
| --- | --- | --- |
| `VNC_DISPLAY` | `:1` | X display number |
| `VNC_WEBSOCKET_PORT` | `6901` | HTTPS web/websocket port |
| `VNC_GEOMETRY` | `1920x1080` | desktop size |
| `VNC_DEPTH` | `24` | colour depth |
| `VNC_USER` | `kasm_user` | KasmVNC HTTP Basic user |
| `VNC_PASSWORD` | `kasmvnc` | password, at least 6 characters |
| `EDA_MODULES` | empty | modules loaded in the X session |

The image has no `ENTRYPOINT`; a command after the image name replaces
`eda-vnc`:

```sh
# shell with no tool loaded
nerdctl run -it --rm local.io/synopsys/synopsys:2025.06 bash

# one tool, environment scoped by its module
nerdctl run -it --rm local.io/synopsys/synopsys:2025.06 \
  bash -lc 'module load dc; dc_shell -f run.tcl'
```

## Kubernetes

```bash
kubectl -n synopsys apply -f synopsys/2025.06/k8s/synopsys-vnc.yaml
kubectl -n synopsys port-forward svc/synopsys-vnc 6901:6901
```

Open <https://127.0.0.1:6901/>. The manifest mounts `/data2` at `/data2`, uses
`/work` as the working directory and requests 4 CPU / 16 Gi. A copy with
placeholders is in [../examples/synopsys-vnc.yaml](../examples/synopsys-vnc.yaml).
