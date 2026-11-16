# Synopsys EDA build definitions

Containerfiles and support scripts for the cluster's Synopsys EDA images. Only
text sources are versioned; the multi-GB vendor payloads live untracked in the
working tree next to them and are read from there by the builds.

## Layout

Each tool is a directory named after the tool with one subdirectory per release
(`<tool>/<version>/`), and the version is the image tag. A second release is
therefore a sibling directory rather than an in-place rewrite.

| Directory | Contents |
| ----------- | ------------------------------------------------------------ |
| `base/` | `synopsys/build:8.10` (Installer + `ValidationTool`, which validates the integrity of the Synopsys EDA tools) and `synopsys/runtime:8.10` (X11/GL/libstdc++/FlexLM deps) |
| `scl/2025.03/` | FlexLM license server and its `k8s/` manifest |
| `vcs/`, `verdi/`, `lc/`, `spyglass/`, `dc/`, `fc/`, `fm/`, `pt/`, `vcst/` | one directory per built release, each with its Containerfile, `flist` payload manifest and start probe; vendor-tree patches are explained in that tool's `docs/` |
| `vip/2023.12/` | VIP compile-time tree, shipped as a read-only image volume |
| `ciel/` | open PDK packaging (pristine and DC-ready images) |
| `synopsys/2025.06/` | every tool + VIP + PDKs in one module-managed KasmVNC desktop image, assembled from the product images |
| `ASAP7/` | ASAP7 PDK store tooling and the host-mounted `pdk/asap7` trees |
| `docs/` | build, CI, runtime dependency and licensing details |
| `skills/synopsys/` | agent skill for running the built images: jobs, licenses, PDKs, VIP and the desktop |
| `.github/` | image build workflow and its product-selection script |

## Payloads

A clone is text-only: the installer, `ValidationTool`, the `*.spf` /
`*.spf.partNN` volumes and the PDK archives must be staged from the vendor
delivery before anything can be built. The `flist` next to each Containerfile
lists exactly which files that build needs. Payloads are not archived anywhere,
so keep the delivery for as long as the images built from it are in use.

## Images

Images are `local.io/synopsys/<product>:<version>`, tagged with the tool version
only. Each single-tool image's entry point is the product CLI, so a pod without
`command:` (or `nerdctl run -it <image>`) starts the tool and extra arguments
pass through, e.g. `nerdctl run --rm <image> -f run.tcl`. Use
`--entrypoint /bin/bash` (or `command: ["bash"]`) for a shell; in the `synopsys`
image the `CMD` starts the KasmVNC desktop.

`local.io` is this cluster's private image registry, so it is a placeholder in
this repository rather than a public address. If you reuse this layout, replace
`local.io` with your own private registry host: it appears in the Containerfiles'
`EDABASE` defaults, the `k8s/` manifests, the CI workflow and the skill examples,
and the BuildKit push target in `docs/build.md`.

| Product | Image | Entry point |
| --- | --- | --- |
| `base` | `synopsys/build:8.10`, `synopsys/runtime:8.10` | `bash` |
| `scl` | `synopsys/scl:2025.03` | `entrypoint.sh` (license server) |
| `vcs` | `synopsys/vcs:2025.06-SP1`, `synopsys/vcs:2023.12-SP2` | `vcs` |
| `verdi` | `synopsys/verdi:2025.06-SP1`, `synopsys/verdi:2023.12-SP2` | `verdi` |
| `lc` | `synopsys/lc:2025.06` | `lc_shell` |
| `spyglass` | `synopsys/spyglass:2025.06` | `spyglass` (`sg_shell` for the Tcl shell) |
| `fm` | `synopsys/fm:2025.06` | `fm_shell` |
| `pt` | `synopsys/pt:2025.06` | `pt_shell` |
| `dc` | `synopsys/dc:2025.06-SP4` | `dc_shell` |
| `fc` | `synopsys/fc:2025.06` | `fc_shell` |
| `vcst` | `synopsys/vcst:2025.06-SP2` | `vc_static_shell` |
| `synopsys` | `synopsys/synopsys:2025.06` | `eda-vnc` (KasmVNC web desktop) |
| `vip` | `synopsys/vip:2023.12` | — (image volume) |
| `ciel` | `synopsys/ciel-pdk:2026.11`, `synopsys/ciel-pdk-dc:2026.11` | — (image volume) |

No image sets a license server address: jobs pass `SNPSLMD_LICENSE_FILE` and
`LM_LICENSE_FILE` in their `env` (`2700@license` inside `synopsys`).

## Build

Images are built and pushed by CI on the cluster's Gitea runner. **Do not build
them by hand.** A push to `main` rebuilds only the images whose sources changed;
to rebuild anything else, dispatch *Actions → Build EDA images* from the
workflow (choose a product or `all`).

Every tool image ends with its own start probe, so an image that cannot start
the tool fails before it is pushed. See
[`docs/build.md`](docs/build.md) for the layering, the BuildKit invocation, the
`flist`/payload rules and the probes, and [`docs/ci.md`](docs/ci.md) for the
path-to-image mapping and dispatch preconditions.

## Further reading

| Doc | Contents |
| --- | --- |
| [`docs/build.md`](docs/build.md) | payload staging, layering and base images, BuildKit command, EST `.spf.partNN` volumes, start probes |
| [`docs/ci.md`](docs/ci.md) | workflow, what a push rebuilds, manual dispatch |
| [`docs/runtime-deps.md`](docs/runtime-deps.md) | how the runtime stage's library set was audited |

Per-directory notes: [`synopsys/2025.06/`](synopsys/2025.06/README.md),
[`vip/2023.12/`](vip/2023.12/README.md), [`ciel/`](ciel/README.md),
[`ASAP7/`](ASAP7/README.md).

Container quirks are documented next to the tool that hits them, because they
are about that vendor tree and its Containerfile:
[`pt/2025.06/docs/`](pt/2025.06/docs/container-quirks.md),
[`fm/2025.06/docs/`](fm/2025.06/docs/container-quirks.md),
[`lc/2025.06/docs/`](lc/2025.06/docs/container-quirks.md),
[`fc/2025.06/docs/`](fc/2025.06/docs/container-quirks.md),
[`spyglass/2025.06/docs/`](spyglass/2025.06/docs/container-quirks.md),
[`verdi/docs/`](verdi/docs/container-quirks.md).
