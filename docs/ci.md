# CI

`.github/workflows/build-images.yaml` builds the images with the cluster's
BuildKit service and pushes them to the cluster registry. **Images are built by
CI only — do not build them by hand.**

The workflow is plain GitHub Actions: no marketplace actions, no `secrets`, and
the only contexts it reads (`github.*`, `inputs.*`, `github.event.before`) are
implemented by both, and Gitea falls back to `.github/workflows` when there is
no `.gitea/workflows`. What does not travel is the environment: the jobs need a
runner with `/data2/synopsys` mounted, the buildkit Service and the cluster
registry, so they only run on the cluster's Gitea runner.

## What a push rebuilds

A push to `main` builds the images whose sources it touched:

| Changed path | Images rebuilt |
| --- | --- |
| `base/Containerfile.build` | `build`, then every image built on it (`scl`, `vcs`, `verdi`, `lc`, `spyglass`, `fm`, `pt`, `dc`, `fc`, `vcst`, `vip`, and `synopsys` through the product images) |
| `base/Containerfile.runtime` | `runtime`, then every image built on it (`vcs`, `verdi`, `lc`, `spyglass`, `fm`, `pt`, `dc`, `fc`, `vcst`, and `synopsys`; `scl` and `vip` do not use it) |
| `<product>/<version>/` | that image; `synopsys` too when the release is one it copies (the `FROM` list in `synopsys/2025.06/Containerfile`) |
| `vip/2023.12/`, `ciel/` | that image, plus `synopsys` |
| `synopsys/2025.06/` | `synopsys` only |
| `.github/` | nothing; the run only exercises the workflow itself |

The tools matrix has one entry per **built release**, so `vcs` and `verdi`
appear twice (`2025.06-SP1` and `2023.12-SP2`) and each entry pushes its own
tag: a push selects only the release directory that changed, while dispatching
the product name rebuilds all of its releases.

The path-to-image mapping and the push range handling live in
[`.github/scripts/select-products.sh`](../.github/scripts/select-products.sh);
it is also what `workflow_dispatch` uses, so a run is only ever one code path. A
range that cannot be resolved (first push of a branch, force push, shallow
checkout) rebuilds everything rather than silently skipping an image, and
[`.github/scripts/select-products.test.sh`](../.github/scripts/select-products.test.sh)
covers those cases — run it after touching the mapping. `ciel` is `FROM
scratch`, so a base Containerfile change does not rebuild it.

Because `synopsys` is assembled from the product images it runs as its own job
with `needs: [tools, vip, ciel]`, after those have finished. The product jobs
that skipped their build (nothing changed) leave the image already in the
registry, which is what the assembly consumes.

## Manual dispatch

Dispatch *Actions → Build EDA images* to rebuild an image whose sources did not
change (pick a product, or `all` for the two bases followed by every tool):

- the job pods read `/data2/synopsys` directly, so the payloads have to be in
  place on that GPFS mount before the run (`synopsys/2025.06/` needs only
  `synopsys/2025.06/fetch-kasmvnc.sh` for the KasmVNC RPM);
- the build refuses to run if the tracked files of the selected product differ
  from the pushed/dispatched commit (`allow_dirty` overrides that on dispatch);
- every image gets a registry cache (`<image>-cache`), so a rebuild only redoes
  the changed layers;
- a new push to `main` cancels the previous run of this workflow on that branch.

Start probes are part of the image build itself; see
[`build.md`](build.md#start-probe).
