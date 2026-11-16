# Runtime dependency audit

What the runtime stage has to provide was measured, not guessed. For each
product the installed tree was dumped with `readelf -d` (all `*.so*` and
executables) and `readelf -h`, then reduced to the sonames that

* are `DT_NEEDED` by at least one **x86-64** object (Solaris/aarch64/ppc64
  leftovers shipped in the same tree are ignored, otherwise `libc.so.1`,
  `ld-linux-aarch64.so.1` and friends look like missing Linux libraries),
* are not shipped inside the tree itself, and
* are not already provided by `runtime`.

| Product | Unmet sonames needed by `*/bin` or the tool's own `shlib` | Action |
| --- | --- | --- |
| `fm`    | none | `runtime` suffices |
| `pt`    | `libnuma.so.1` (`libmpi.so.1`), `libpng12.so.0` + `liboasis-O.so` (`linux64/syn/bin/common_shell_exec`), `libtcl8.5.so` (`linux64_starrc/bin/ratcl2itf_gf`) | `libnuma` → `numactl-libs` in `runtime`; the other three are el7-era sonames AlmaLinux 8 does not carry |
| `dc`, `fc` | `libtcl8.5.so` (`linux64_starrc/bin/ratcl2itf_gf`, plus `ircx2itf`/`rvl2itf` for `fc`) | same as above |
| `vcs`, `lc`, `vcst` | none | `runtime` suffices |
| `spyglass` | none for the driver and flow binaries (`spyglass`, `spyglass_main`, `sg_shell`; verified with a `sg_shell` run) | `runtime` suffices; the `libudev.so.1` that FlexLM `dlopen`s for the hostid does not show up in a `DT_NEEDED` audit (see [`spyglass/2025.06/docs/container-quirks.md`](../spyglass/2025.06/docs/container-quirks.md)). The bundled graphviz dotty, GTK2/Qt4 helpers and gtkwave are optional GUI tools and are not audited |
| `verdi` | `libxcb-icccm.so.4`, `libxcb-image.so.0`, `libxcb-keysyms.so.1`, `libxcb-render-util.so.0`, `libxcb-util.so.1`, `libxkbcommon.so.0`, `libxkbcommon-x11.so.0` (Qt 5 xcb platform plugin, loaded even by `verdi -id`) | `xcb-util*` and `libxkbcommon*` packages in the `verdi/` Containerfiles; Verdi's own `dlCheck` runs before the wrapper adds its bundled `Qt5/lib/depends/xlib` |

Everything else the audit reported is optional and deliberately **not**
installed: Qt GUI plugins (`libQt5Charts/Gamepad/Multimedia/SerialPort/
TextToSpeech`, `libtiff.so.5`, `libodbc.so.2`, `libpq.so.5`,
`libwayland-cursor.so.0`, the Electron/GTK stack under `fusioncompiler/fcaif_dso`)
and the bundled Python's optional C extensions (`libicudata.so.56`,
`libncursesw.so.5`, `libpanelw.so.5`, `libreadline.so.6`, `libgdbm.so.4`,
`libtcl8.5`/`libtk8.5`). The headless shells never load them, and most of those
sonames do not exist on AlmaLinux 8 at all — a GUI-capable image would need
vendor-compat copies, not extra packages.

Verification is a plain `ldd` sweep inside the finished image; every product
`bin` directory reports no `not found`:

```sh
sudo nerdctl run --rm --entrypoint sh local.io/synopsys/pt:2025.06 \
  -c 'for f in /opt/synopsys/*/*/bin/*; do ldd "$f"; done 2>/dev/null | grep "not found"'
```
