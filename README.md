# Synopsys EDA images

This repository builds and publishes one container image per Synopsys EDA tool.
You run a tool by starting its image with your project directory mounted — as a
Kubernetes Job, with `nerdctl`, or through the desktop image.

The examples use four placeholders. Replace them with your site's values:

- `<registry>` — image registry host, e.g. `registry.example.com`
- `<namespace>` — Kubernetes namespace for the jobs and the license server
- `<data-dir>` — shared directory that holds your projects
- `<pdk-root>` — directory that holds the PDK trees

## Images

Every image is `<registry>/synopsys/<tool>:<release>`. The tag is the tool
version, so a new release is a new tag.

| Tool | Image | Entry point |
| --- | --- | --- |
| all tools + desktop | `synopsys/synopsys:2025.06` | `eda-vnc` |
| VCS | `synopsys/vcs:2025.06-SP1`, `:2023.12-SP2` | `vcs` |
| Verdi | `synopsys/verdi:2025.06-SP1`, `:2023.12-SP2` | `verdi` |
| Design Compiler | `synopsys/dc:2025.06-SP4` | `dc_shell` |
| Fusion Compiler | `synopsys/fc:2025.06` | `fc_shell` |
| PrimeTime | `synopsys/pt:2025.06` | `pt_shell` |
| Formality | `synopsys/fm:2025.06` | `fm_shell` |
| Library Compiler | `synopsys/lc:2025.06` | `lc_shell` |
| SpyGlass | `synopsys/spyglass:2025.06` | `spyglass`, `sg_shell` |
| VC Static / VC Formal | `synopsys/vcst:2025.06-SP2` | `vc_static_shell`, `vcf` |
| VIP | `synopsys/vip:2023.12` | none; mount as a volume |
| open PDKs | `synopsys/ciel-pdk:2026.11`, `:ciel-pdk-dc` | none; mount as a volume |
| license server | `synopsys/scl:2025.03` | `entrypoint.sh` |

The vendor releases behind these tags are listed in
[`references/images.md`](skills/synopsys/references/images.md).

## Run a tool

A single-tool image starts its product CLI, and arguments after the image name
go to that CLI. This runs Design Compiler on `run.tcl` in your project:

```sh
nerdctl run --rm \
  -v /srv/projects:/srv/projects -w /srv/projects/myproj \
  -e SNPSLMD_LICENSE_FILE=2700@<service> \
  -e LM_LICENSE_FILE=2700@<service> \
  <registry>/synopsys/dc:2025.06-SP4 -f run.tcl
```

To get a shell instead of the tool, override the entry point with
`--entrypoint /bin/bash`. In a Pod, leave `command` unset to start the tool, or
set `command: ["bash"]` for a shell.

## Submit a Job

Start from a manifest in [`skills/synopsys/examples/`](skills/synopsys/examples),
change the image, paths and resources, then apply it:

```bash
kubectl -n <namespace> apply -f my-job.yaml
kubectl -n <namespace> get job,pod
kubectl -n <namespace> logs -f job/<name>
kubectl -n <namespace> delete job <name>
```

```yaml
spec:
  template:
    spec:
      restartPolicy: Never
      securityContext: { runAsUser: 1001, runAsGroup: 1001 }
      containers:
        - name: dc
          image: <registry>/synopsys/dc:2025.06-SP4
          workingDir: <data-dir>/<project>
          env:
            - { name: SNPSLMD_LICENSE_FILE, value: 2700@<service> }
            - { name: LM_LICENSE_FILE, value: 2700@<service> }
          resources:
            requests: { cpu: "8", memory: 32Gi }
          volumeMounts:
            - { name: data, mountPath: <data-dir> }
            - { name: pdk, mountPath: /pdks, readOnly: true }
      volumes:
        - { name: data, hostPath: { path: <data-dir> } }
        - { name: pdk, hostPath: { path: <pdk-root>/sky130-dc } }
```

Mount `<data-dir>` at the same path inside the pod so the paths in your scripts
keep working, and mount the PDK read-only at `/pdks`. EDA jobs need CPU and
memory, not a GPU; set `backoffLimit: 0` so a failed run is not retried. If your
cluster uses a batch scheduler such as KAI, add its `schedulerName` to the pod
template.

[`pt-job.yaml`](skills/synopsys/examples/pt-job.yaml) is a complete example. To
submit from CI instead, see
[`references/actions.md`](skills/synopsys/references/actions.md).

## Desktop

The desktop image contains every tool, VIP and the open PDKs, and serves an
XFCE session over KasmVNC on port 6901:

```bash
kubectl -n <namespace> apply -f synopsys/2025.06/k8s/synopsys-vnc.yaml
kubectl -n <namespace> port-forward svc/synopsys-vnc 6901:6901
```

Open <https://127.0.0.1:6901/> and log in as `kasm_user` with password
`kasmvnc`. The certificate is self-signed.

No tool is loaded by default. Load one with its module, or use `eda-shell` to
get a shell with the module already loaded:

```sh
eda-shell dc                   # shell with Design Compiler loaded
module load vcs verdi          # two tools in one shell
module avail
```

The image already contains `/opt/pdk` (DC `.db` views) and `/opt/pdk/pristine`,
so the open PDKs need no mount. Environment variables and the `nerdctl`
equivalent are in [`references/desktop.md`](skills/synopsys/references/desktop.md).

## Licenses

| Where the job runs | Value |
| --- | --- |
| same namespace as the license server | `2700@<service>` |
| another namespace, or a host `nerdctl` run | `2700@<service>.<namespace>` |

To see who holds seats:

```bash
kubectl -n <namespace> exec deploy/license -- \
  lmutil lmstat -c 2700@127.0.0.1 -a
```

The server itself is built from [`scl/2025.03/`](scl/2025.03); its ports and
variables are documented in
[`references/licenses.md`](skills/synopsys/references/licenses.md).

## PDKs and data

Each tree under `<pdk-root>/` is a PDK root. Mount the one your flow needs
read-only at `/pdks` and set `PDK_ROOT=/pdks`.

| Tree | Use it for |
| --- | --- |
| `sky130-dc`, `gf180mcu-dc`, `ihp-sg13-dc`, `freepdk45-dc` | DC, PT, FM (compiled `.db` views) |
| `sky130`, `gf180mcu`, `ihp-sg13`, `freepdk45` | flows that need the pristine tree |
| `asap7`, `asap7-dc` | ASAP7; no `PDK_ROOT` layout, pass file paths |
| `smic-l28hpc-r1p0` | SMIC 28HPC+; no `PDK_ROOT` layout, pass file paths |

Library and view paths are in [`references/pdks.md`](skills/synopsys/references/pdks.md).
For VIP, mount `synopsys/vip:2023.12` at `/opt/designware` and set
`DESIGNWARE_HOME=/opt/designware`
([`references/vip.md`](skills/synopsys/references/vip.md)).

## Examples

| Task | Manifest |
| --- | --- |
| DC, sky130 | [`dc-sky130-job.yaml`](skills/synopsys/examples/dc-sky130-job.yaml) |
| DC, ASAP7 | [`dc-asap7-job.yaml`](skills/synopsys/examples/dc-asap7-job.yaml) |
| DC, SMIC 28HPC+ | [`dc-smic-job.yaml`](skills/synopsys/examples/dc-smic-job.yaml) |
| PrimeTime | [`pt-job.yaml`](skills/synopsys/examples/pt-job.yaml) |
| VCS | [`vcs-job.yaml`](skills/synopsys/examples/vcs-job.yaml) |
| desktop | [`synopsys-vnc.yaml`](skills/synopsys/examples/synopsys-vnc.yaml) |
| CI workflow | [`actions-job.yaml`](skills/synopsys/examples/actions-job.yaml) |

The manifests contain site values; replace them before applying.

## Maintainers

CI (`.github/workflows/build-images.yaml`) builds and pushes every image. Each
tool lives in `<tool>/<version>/` with a Containerfile, an `flist` payload
manifest and a start probe. The probe runs at the end of the build, so an image
whose tool cannot start fails before it is pushed.

Vendor payloads are untracked and not archived. To build images from this
repository yourself, first place the payload files in each `<tool>/<version>/`
directory: every file named in that directory's `flist` must be present before
the build runs.

| Topic | File |
| --- | --- |
| Layering, BuildKit, payloads, probes | [`docs/build.md`](docs/build.md) |
| Path-to-image mapping, dispatch, variables | [`docs/ci.md`](docs/ci.md) |
| Runtime dependency audit | [`docs/runtime-deps.md`](docs/runtime-deps.md) |
