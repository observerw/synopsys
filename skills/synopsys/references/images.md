# Images

Images are `local.io/synopsys/<product>:<version>` and are built by CI from this
repository. For a single product the tag is the version directory, so a release
change is a new tag. The assembled `synopsys:2025.06` tag is re-pushed in place
when a product image it copies changes, so re-check it instead of trusting a
node's cached copy.

| Image | Vendor release | Tool and entry point |
| --- | --- | --- |
| `local.io/synopsys/synopsys:2025.06` | X-2025.06 | every tool, VIP, open PDKs and a KasmVNC desktop; `eda-vnc` |
| `local.io/synopsys/vcs:2025.06-SP1` | X-2025.06-SP1 | VCS; `vcs` |
| `local.io/synopsys/vcs:2023.12-SP2` | X-2023.12-SP2 | VCS; `vcs` |
| `local.io/synopsys/verdi:2025.06-SP1` | X-2025.06-SP1 | Verdi; `verdi` |
| `local.io/synopsys/verdi:2023.12-SP2` | X-2023.12-SP2 | Verdi; `verdi` |
| `local.io/synopsys/dc:2025.06-SP4` | X-2025.06-SP4 | Design Compiler; `dc_shell` |
| `local.io/synopsys/fc:2025.06` | X-2025.06 | Fusion Compiler; `fc_shell` |
| `local.io/synopsys/pt:2025.06` | X-2025.06 | PrimeTime; `pt_shell` |
| `local.io/synopsys/fm:2025.06` | X-2025.06 | Formality; `fm_shell` |
| `local.io/synopsys/lc:2025.06` | X-2025.06 | Library Compiler; `lc_shell` |
| `local.io/synopsys/spyglass:2025.06` | X-2025.06 | SpyGlass; `spyglass`, `sg_shell` |
| `local.io/synopsys/vcst:2025.06-SP2` | X-2025.06-SP2 | VC Static / VC Formal; `vc_static_shell`, `vcf` |
| `local.io/synopsys/vip:2023.12` | V-2023.12 | VIP compile-time tree; image volume, no entry point |
| `local.io/synopsys/ciel-pdk:2026.11`, `:ciel-pdk-dc` | 2026.11 | open PDK file images; image volume, no entry point |
| `local.io/synopsys/scl:2025.03` | — | FlexLM license server; `entrypoint.sh` |
| `local.io/synopsys/build:8.10` | — | build stage: Installer and `ValidationTool`; `bash` |
| `local.io/synopsys/runtime:8.10` | — | runtime base: X11/GL/libstdc++/FlexLM; `bash` |

## Run one tool

A single-tool image's entry point is the product CLI and extra arguments pass
through:

```sh
nerdctl run --rm local.io/synopsys/dc:2025.06-SP4 -f run.tcl
nerdctl run --rm --entrypoint /bin/bash local.io/synopsys/pt:2025.06
```

In a Pod, the same split uses `command`: omit it to start the tool with the
image arguments, or set `command: ["bash"]` for a shell.

The desktop image has no `ENTRYPOINT`; a command after the image name replaces
`eda-vnc`.

## Notes

- Images carry no license server address; set the license variables in the Job
  `env` ([licenses.md](licenses.md)).
- The product images run their own start probe as the final build step, so an
  image that cannot start the tool fails the build instead of reaching the
  registry.
- `vip` and `ciel-pdk` are file images; mount them, do not run them
  ([vip.md](vip.md)).
- When a version directory under this repository is added or removed, update
  this table and the image table in [SKILL.md](../SKILL.md).
