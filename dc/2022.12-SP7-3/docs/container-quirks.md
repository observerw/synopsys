# Design Compiler 2022.12 container quirks

## 1. el7-era libraries behind `dc_shell`

`bin/dc_shell` is the usual wrapper: it ends up in
`linux64/syn/bin/common_shell_exec`, which is an el7-era binary. Two of its
`DT_NEEDED` entries are not in `runtime` and not in the tool tree:

| Soname | Where it comes from |
| --- | --- |
| `libpng12.so.0` | not in AlmaLinux 8 at all (`libpng` is 1.6 there); unpacked from the CentOS 7 `libpng12` package into `/opt/synopsys-compat` |
| `libpulse.so.0`, `libpulse-mainloop-glib.so.0` | `pulseaudio-libs`, `pulseaudio-libs-glib2` |

Without them the loader fails before the tool runs:

```
.../linux64/syn/bin/common_shell_exec: error while loading shared libraries:
libpng12.so.0: cannot open shared object file: No such file or directory
```

The rest of `common_shell_exec`'s dependencies (`Qt 5` including WebKit,
`libtbb.so.12`, `libprotobuf.so.19`, `liboasis-O.so`, `libXss`) are shipped
under `linux64/syn/shlib`, and the X11/freetype/fontconfig set comes from
`runtime`. The compat directory is exported through `LD_LIBRARY_PATH`, which the
wrapper preserves and extends with the tool's own `lib/linux64`.

## 2. The site license cannot authorize this release

With the license server configured, startup stops at

```
FlexNet Licensing checkout error: Invalid (inconsistent) license key.
Feature:       Synopsys-Release
FlexNet Licensing error:-8,544
[SCL] Authorization failed Design-Compiler 2022.12
Fatal: Design Compiler is not enabled. (DCSH-1)
```

The server serves every Synopsys feature at version `2025.12` (99 seats each),
and this release's SCL client rejects those signatures instead of accepting them
as a newer-than-requested version. Newer images (`dc:2025.06-SP4`) check out
from the same server, so the file itself is fine — it just cannot be used by
this client.

`smoke.sh` therefore probes the binary with `dc_shell -version` (no license
needed, but the wrapper, loader and library set are all exercised) and only runs
the Tcl probe when a checkout succeeds. To run this image for real, point
`SNPSLMD_LICENSE_FILE` at a license server whose feature versions are `2022.12`
or older.
