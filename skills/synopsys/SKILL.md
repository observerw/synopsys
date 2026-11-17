---
name: synopsys
description: "Use this skill when running Synopsys EDA jobs on the gpu cluster: VCS, Verdi, Design Compiler, Fusion Compiler, PrimeTime, Formality, Library Compiler, SpyGlass, VC Static, VIP and the all-in-one KasmVNC desktop, including license checkout, PDK mounting and job submission in the `synopsys` namespace."
---

# Synopsys EDA

## Images

| Image | Tool | Entry point |
| --- | --- | --- |
| `local.io/synopsys/synopsys:2025.06` | all tools, VIP, open PDKs and a KasmVNC desktop | `eda-vnc` |
| `local.io/synopsys/vcs:2025.06-SP1`, `:2023.12-SP2` | VCS | `vcs` |
| `local.io/synopsys/verdi:2025.06-SP1`, `:2023.12-SP2` | Verdi | `verdi` |
| `local.io/synopsys/dc:2025.06-SP4`, `:2022.12-SP7-3` | Design Compiler | `dc_shell` |
| `local.io/synopsys/fc:2025.06` | Fusion Compiler | `fc_shell` |
| `local.io/synopsys/pt:2025.06` | PrimeTime | `pt_shell` |
| `local.io/synopsys/fm:2025.06` | Formality | `fm_shell` |
| `local.io/synopsys/lc:2025.06` | Library Compiler | `lc_shell` |
| `local.io/synopsys/spyglass:2025.06` | SpyGlass | `spyglass` (`sg_shell` for Tcl) |
| `local.io/synopsys/vcst:2025.06-SP2` | VC Static / VC Formal | `vc_static_shell` (`vcf`) |
| `local.io/synopsys/vip:2023.12` | VIP compile-time tree | image volume, `DESIGNWARE_HOME` |
| `local.io/synopsys/scl:2025.03` | FlexLM license server | `entrypoint.sh` |

- Tags are the tool versions; [images.md](references/images.md) lists the vendor releases and the base images.
- A single-tool image starts its product CLI, so `nerdctl run --rm <image> -f run.tcl` runs the tool. Pass `--entrypoint /bin/bash` for a shell.
- No image sets a license server address; set both license variables in the Job `env`.

## License

- Server: `synopsys/license` ClusterIP, `2700` lmgrd, `2701` snpslmd; `synopsys/lic1` is an alias of the same pods.
- Set `SNPSLMD_LICENSE_FILE` and `LM_LICENSE_FILE` to `2700@license` in `synopsys`, or `2700@license.synopsys` from another namespace or a workspace container.
- Every feature reports 99 seats; concurrency is limited by CPU and memory quota.
- Check seats: `kubectl -n synopsys exec deploy/license -- lmutil lmstat -c 2700@127.0.0.1 -a`.
- Details and the license server image: [licenses.md](references/licenses.md).

## Run a Job

```bash
kubectl -n synopsys apply -f examples/dc-sky130-job.yaml
kubectl -n synopsys get job,pod,podgroup
kubectl -n synopsys logs job/<name>
kubectl -n synopsys delete job <name>
```

- Jobs run in namespace `synopsys`; set `schedulerName: kai-scheduler` to use KAI Scheduler.
- Mount `/data2` at `/data2`, the selected PDK root read-only at `/pdks`, and set `resources.requests.cpu` and `memory`.
- Run as user 1001 so outputs stay owned by the workspace user.
- Manifest fields and scheduling: [jobs.md](references/jobs.md).
- From a Gitea Actions workflow: [actions.md](references/actions.md).

## Desktop

`local.io/synopsys/synopsys:2025.06` starts KasmVNC on port `6901` with XFCE and loads nothing by default. Tool environments come from modulefiles:

```sh
eda-shell dc                   # bash with Design Compiler loaded
module load vcs verdi          # several tools in one shell
module avail
```

- Run it with `nerdctl run` or apply the repository's `synopsys/2025.06/k8s/synopsys-vnc.yaml`.
- The image bakes `/opt/pdk` (DC `.db` views) and `/opt/pdk/pristine`.
- Variables, modules and the Kubernetes manifest: [desktop.md](references/desktop.md).

## VIP

Mount `local.io/synopsys/vip:2023.12` as a read-only image volume at `/opt/designware` and set `DESIGNWARE_HOME=/opt/designware`. The VCS image carries the `perl` and setup helpers the VIP examples need. See [vip.md](references/vip.md).

## PDKs

- Each directory under `/data2/synopsys/pdk/` is a PDK root; mount the chosen one read-only at `/pdks`.
- `sky130-dc`, `gf180mcu-dc`, `ihp-sg13-dc`, `freepdk45-dc` and `asap7-dc` carry the compiled `.db` views for DC, PT and FM.
- `asap7-dc` and `smic-l28hpc-r1p0` have no `PDK_ROOT`/variant layout; point the flow at individual files or library globs.
- Paths and library commands: [pdks.md](references/pdks.md).

## References

| Topic | File |
| --- | --- |
| Image tags, vendor releases and one-off runs | [images.md](references/images.md) |
| Job manifest fields and KAI scheduling | [jobs.md](references/jobs.md) |
| License server, environment variables and seat checks | [licenses.md](references/licenses.md) |
| PDK roots and library/view paths | [pdks.md](references/pdks.md) |
| All-in-one KasmVNC image and modules | [desktop.md](references/desktop.md) |
| VIP image volume and VCS setup | [vip.md](references/vip.md) |
| Submitting from Gitea Actions | [actions.md](references/actions.md) |

## Examples

| Job | Files |
| --- | --- |
| Design Compiler, sky130 synthesis | [dc-sky130-job.yaml](examples/dc-sky130-job.yaml), [dc-sky130/](examples/dc-sky130) |
| Design Compiler, ASAP7 synthesis | [dc-asap7-job.yaml](examples/dc-asap7-job.yaml), [dc-asap7/](examples/dc-asap7) |
| Design Compiler, SMIC 28HPC+ | [dc-smic-job.yaml](examples/dc-smic-job.yaml) |
| PrimeTime | [pt-job.yaml](examples/pt-job.yaml) |
| VCS compile and simulation | [vcs-job.yaml](examples/vcs-job.yaml), [vcs/](examples/vcs) |
| KasmVNC desktop Pod and Service | [synopsys-vnc.yaml](examples/synopsys-vnc.yaml) |
| Design Compiler from a Gitea Actions workflow | [actions-job.yaml](examples/actions-job.yaml) |

Copy a Job example next to its inputs under `/data2/<user>/<project>`, replace that path, and apply. `actions-job.yaml` is a workflow for `.gitea/workflows/`.

## Related Skills

- Nodes and `/data2` storage: `cluster`.
- Actions workflows, the `eda` runner label and the `gitea-job` identity: `gitea`.
- LibreLane and the open-source RTL-to-GDSII flow: `eda`.
