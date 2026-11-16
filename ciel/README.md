# Open PDK images (CIEL)

The newest [CIEL](https://github.com/fossi-foundation/ciel) release of every
open PDK family is baked into two scratch images:

| Image | Contents |
| --- | --- |
| `local.io/synopsys/ciel-pdk:2026.11` | the unpacked `PDK_ROOT` tree exactly as CIEL publishes it (`.lib`, `.lef`, `.gds`, ...) |
| `local.io/synopsys/ciel-pdk-dc:2026.11` | the same tree plus Design Compiler `.db` views compiled for the typical (TT) corner |

Both are meant to be mounted as Kubernetes **image volumes**, not run. The
downloaded `tar.zst` release assets under `archives/` are only the input:
`fetch_pdks.py` downloads them, `unpack_pdks.py` reconstructs the `PDK_ROOT`
tree, `compile_db.sh` fills the `-dc` copy with `.db` files, and CI builds and
pushes both images. Nothing is pushed as a separate ORAS artifact.

## Versions

CIEL versions a PDK by the upstream commit its release was built from, so each
family has its own version. `fetch_pdks.py` takes the first entry of the same
manifest `ciel ls-remote` reads — the newest release, which for `ihp-sg13` and
`freepdk45` is currently an upstream pre-release.

| Family | Version | Released | Pre-release | Variants | Assets | Compressed |
| --- | --- | --- | --- | --- | --- | --- |
| `freepdk45` | `784b1a483a5f4de362d6f3629378de1199453f3c` | 2026-09-30 | yes | freepdk45 | 3 | 0.01 GiB |
| `gf180mcu` | `792ef67037d74c8c51811eab3ce23cf793491296` | 2026-10-19 | no | gf180mcuA, gf180mcuB, gf180mcuC, gf180mcuD | 16 | 0.64 GiB |
| `ihp-sg13` | `89d42ee6d2fd9b50b86a1aada6fee6673c3e6008` | 2026-10-16 | yes | ihp-sg13g2, ihp-sg13cmos5l | 8 | 0.47 GiB |
| `sky130` | `792ef67037d74c8c51811eab3ce23cf793491296` | 2026-10-19 | no | sky130A, sky130B | 13 | 2.75 GiB |

Unpacked the tree is about 21 GiB; the exported image layer is 4.3 GiB.

## Layout

`unpack_pdks.py` rebuilds the tree `ciel enable` would install, including the
relative variant symlinks:

```
pdk/
├── versions.json
├── sky130A -> ciel/sky130/versions/792ef670.../sky130A
├── sky130B -> ciel/sky130/versions/792ef670.../sky130B
├── gf180mcuD -> ciel/gf180mcu/versions/792ef670.../gf180mcuD
├── ihp-sg13g2 -> ciel/ihp-sg13/versions/89d42ee6.../ihp-sg13g2
├── freepdk45 -> ciel/freepdk45/versions/784b1a48.../freepdk45
└── ciel/<family>/versions/<version>/<variant>/{libs.ref,libs.tech}
```

`pdk/` is the build context of `Containerfile.pdk`; `pdk-dc/` is an identical
tree plus `db/` directories and is the context of `Containerfile.pdk-dc`.
Both use a `FROM scratch` / `COPY . /` image.
An image volume exposes the image's root filesystem, so the PDK tree is copied
to the image root and the mount point is `/pdk`: setting `PDK_ROOT=/pdk` makes
every variant resolve.

## Download and unpack

Both steps read only `fossi-foundation.github.io/ciel-releases` and the GitHub
release assets it points at. From a host that needs the outbound proxy:

```sh
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890
cd ciel
python3 fetch_pdks.py            # -> archives/<family>-<version>/*.tar.zst
python3 unpack_pdks.py           # -> pdk/
```

`archives/versions.json` pins the family versions, asset URLs and sha256;
`fetch_pdks.py` is restartable and skips files that are already present, and
`unpack_pdks.py` deletes and rebuilds `pdk/` from the archives.

## DC views (.db)

`.db` files are generated into a copy of the tree:

```sh
cp -al pdk pdk-dc                                  # hardlink copy, cheap on GPFS
kubectl apply -f ciel/k8s/compile-db-job.yaml      # writes pdk-dc/**/db/*.db
```

`compile_db.sh` runs `lc_shell` for every typical-corner `.lib` and writes the
result next to it:

```
pdk-dc/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
pdk-dc/sky130A/libs.ref/sky130_fd_sc_hd/db/sky130_fd_sc_hd__tt_025C_1v80.db
```

DC can then use the views directly:

```tcl
set target_library [glob /pdk/sky130A/libs.ref/*/db/*tt_025C_1v80*.db]
set link_library   "* $target_library"
```

The job reuses the `lc` image and checks out a Library-Compiler license from
`license`. 435 of the 443 typical-corner libraries are produced. The eight
missing ones are `gf180mcu_{as,ocd}_sc_*`: LC X-2025.06 rejects their Liberty
(missing timing arcs, flip-flops with both clear and preset) and refuses to
write a library, so they are absent from the `-dc` image rather than partially
patched. `compile_db.sh` strips a few newer Liberty attributes LC cannot read
(`related_bus_pins`, `related_{ground,power}_pin`) from a temporary copy; the
original `.lib` files in both images are untouched.

ASAP7 is not part of this directory. Its checkout, store tooling and `.db` job
live in [`../ASAP7/`](../ASAP7/README.md).

## Build the images

CI builds both images on a push that touches `ciel/`, or dispatch *Build EDA
images* with `product = ciel` (or `all`); the job builds both contexts
(`${SOURCE_DIR}/ciel/pdk` and `.../pdk-dc`) and pushes both references.
The tag comes from `CIEL_VERSION` in `.github/workflows/build-images.yaml`;
bump it there, update the same value in `ciel/k8s/` and `demo/argo/`, then
dispatch `product = all` so both the CIEL images and `synopsys` are rebuilt
with the new tag.
`pdk/`, `pdk-dc/` and `archives/` are gitignored and have to be present on the
`/data2` mount before the job runs.

## Pull / mount

The kubelet pulls the images through the node-local containerd mapping and
unpacks them once per node. To inspect one from a shell, use the registry
address with `--plain-http`:

```sh
sudo nerdctl pull --plain-http 10.196.10.52:32767/synopsys/ciel-pdk-dc:2026.11
```

The images are consumed as image volumes — see
[`k8s/pdk-image-volume.yaml`](k8s/pdk-image-volume.yaml) and
[`k8s/pdk-dc-image-volume.yaml`](k8s/pdk-dc-image-volume.yaml):

```yaml
volumes:
  - name: pdk
    image:
      reference: local.io/synopsys/ciel-pdk-dc:2026.11
      pullPolicy: IfNotPresent
```

The kubelet unpacks the image once per node and mounts it read-only; no
hostPath, NFS or unpack step is involved.

## License note

The PDKs are published by their upstream projects (SkyWater/Google, GlobalFoundries,
IHP, NCSU) through CIEL. Their licenses travel inside the archives under each
variant's `libs.ref`/`libs.tech` directories; review them before redistribution.
