# ASAP7

ASAP7 is not a CIEL release and is not built as its own image. Everything ASAP7
lives under this directory, and the dc-ready `pdk/asap7-dc` tree is mounted at
`/pdks` by the jobs that use it (it is not baked into the `synopsys/` image):

| Path | Tracked | Contents |
| --- | --- | --- |
| `asap7/` | no | upstream checkout (`The-OpenROAD-Project/asap7`, superproject + five submodules, ~19 GB) |
| `asap7_snps/` | no | Synopsys supplement (`snishizawa/asap7_snps`: IC Compiler tech file, StarRC ITF) |
| `compile_db.sh` | yes | compile extracted ASAP7 Liberty files to DC `.db` views in place |
| `k8s/compile-db-job.yaml` | yes | run `compile_db.sh` in the `lc` image against `pdk/asap7-dc` |
| `README.md` | yes | this file |

The two payload directories are gitignored; re-fetch them as documented in
`.gitignore`. They are hardlink-mirrored into the host PDK store as `pdk/asap7`
and `pdk/asap7-dc` (see [`../pdk/README.md`](../pdk/README.md)). ASAP7 is not
packaged into any image: the jobs that need it mount `pdk/asap7-dc` at `/pdks`.

This directory also holds the one preparation step that the store needs beyond
the mirror: unpacking the Liberty archives and compiling Design Compiler `.db`
views for the `-dc` tree. It is deliberately independent of `ciel/`.

## Prepare the `-dc` tree

```sh
cd /data2/synopsys
cp -al pdk/asap7 pdk/asap7-dc

# ASAP7 publishes Liberty as *.lib.7z; the lc image ships no 7z, so extract on
# the host. This is the TT corner of the current 7.5-track library.
cd pdk/asap7-dc/asap7sc7p5t_28/LIB/NLDM
7z x -y '*_TT_*.7z'
```

Extract other corners or the older `asap7sc7p5t_27`, `asap7sc6t_26` and SRAM
archives the same way; `compile_db.sh` picks up any `.lib` under
`asap7sc7p5t_*/LIB/NLDM`, `asap7sc6t_*/LIB/NLDM` and
`asap7_sram_*/generated/LIB`.

## Compile the `.db` views

```sh
kubectl apply -f ASAP7/k8s/compile-db-job.yaml
```

The job mounts `pdk/` at `/pdk` and runs `compile_db.sh` against
`/pdk/asap7-dc` with 8 parallel `lc_shell` processes. Output:

```
pdk/asap7-dc/asap7sc7p5t_28/LIB/db/*.db              # 20 cell views for the TT corner
pdk/asap7-dc/asap7_sram_0p0/generated/db/*.db        # 36 SRAM macros
```

`compile_db.sh` skips libraries that already have a non-empty `.db`, so it is
safe to rerun after extracting more corners. On a host with `lc_shell` and a
license, the same script can run directly:

```sh
ASAP7/compile_db.sh /data2/synopsys/pdk/asap7-dc 8
```

## Notes

- `lc_shell` X-2025.06 writes the `.db` and then segfaults on exit in the `lc`
  image, so success is decided by the output file, not the exit status.
- The SRAM macro Liberty names an `output_voltage` supply group LC does not
  derive (LBDB-235); the script retries those from a copy without that single
  attribute, keeping the `pg_pin` and `voltage_map` entries.
- The pristine `pdk/asap7` tree keeps `LIB/NLDM` and `LIB/CCS` as `*.lib.7z`
  archives and has no `db/` directories. Only the hardlink copy `pdk/asap7-dc`
  is written by the job.

## Use

Mount `pdk/asap7-dc` at `/pdks` and read the compiled views:

```tcl
set target_library [glob /pdks/asap7sc7p5t_28/LIB/db/*_RVT_TT_*.db]
set link_library   "* $target_library"
```

A working example is in the `synopsys` skill:
`skills/synopsys/examples/dc-asap7-job.yaml`.
