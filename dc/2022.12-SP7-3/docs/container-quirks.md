# Design Compiler 2022.12 container quirks

## 1. el7-era libraries behind `dc_shell`

`bin/dc_shell` is the usual wrapper: it ends up in
`linux64/syn/bin/common_shell_exec`, which is an el7-era binary. Two groups of
its `DT_NEEDED` entries are not in `runtime` and not in the tool tree:

| Soname | Where it comes from |
| --- | --- |
| `libpng12.so.0` | not in AlmaLinux 8 at all (`libpng` there is 1.6); unpacked from the CentOS 7 `libpng12` package into `/opt/synopsys-compat` |
| `libpulse.so.0`, `libpulse-mainloop-glib.so.0` | `pulseaudio-libs`, `pulseaudio-libs-glib2` |

Without them the loader fails before the tool runs:

```
.../linux64/syn/bin/common_shell_exec: error while loading shared libraries:
libpng12.so.0: cannot open shared object file: No such file or directory
```

The rest of `common_shell_exec`'s dependencies are covered: Qt 5 (including
WebKit), `libtbb.so.12`, `libprotobuf.so.19`, `liboasis-O.so` and `libXss` are
shipped under `linux64/syn/shlib`, while the X11/freetype/fontconfig/zlib set
comes from `runtime`. The compat directory is exported through
`LD_LIBRARY_PATH`, which the wrapper preserves and extends with the tool's own
`lib/linux64`.

## 2. Startup abort in libudev

Once the libraries are in place the checkout succeeds but `dc_shell` still dies
right after it:

```
Checkout succeeded: Design-Compiler/...
Fatal: Internal system error, cannot recover.

Release = 'U-2022.12-SP7-3'  Architecture = 'linux64'  Program = 'dc_shell'
Stack trace for crashing thread
-------------------------------
SNPSee_...
funlockfile+80
```

This is the same libudev/FlexLM bug as `lc`/`pt`/`fm`/`fc`: the hostid is built
by enumerating `/sys` through libudev, and libudev's `strdup()`-allocated
strings end up in a `realloc()` from another implementation. The image sets

```dockerfile
ENV LD_PRELOAD=/lib64/libudev.so.1
```

so libudev's symbols resolve to its own copy again. Note that the same tree
installed outside the image (`/data2/tmp/...` instead of `/opt/synopsys`) is not
even authorized — its client reports `FlexNet Licensing error:-8,544` — so the
crash only shows up in the built image, not in a hand-installed tree.
