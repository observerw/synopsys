# SpyGlass container quirks

## The libudev crash hides behind `SPYGLASS_LD_PRELOAD`

`spyglass -version` works, but every `sg_shell` and `spyglass -shell` start
aborted before the first prompt with

```
mremap_chunk(): invalid pointer

**** SpyGlass Terminator Signal: 6 [SIGABRT (Abort)].
```

and exit code 3 — with or without a license server configured, because the Tcl
shell starts a checkout as soon as it runs. The abort is in `lc_checkout`, which
builds the hostid by enumerating `/sys` through libudev
(`udev_enumerate_scan_devices` → `strextend_with_separator` → `realloc`), the
same libudev/FlexLM symbol-resolution bug that `lc`, `fc`, `pt` and `fm` hit:
libudev gets its strings from one `strdup()` and hands them to a `realloc()`
from another implementation.

The `LD_PRELOAD=/lib64/libudev.so.1` fix those images use does nothing here,
and that is the trap: `spyglass_main` replaces `LD_PRELOAD` with
`SPYGLASS_LD_PRELOAD` immediately before it execs the checker (only
`libsnps_stp.so` entries from the caller's `LD_PRELOAD` are kept), so an image
`ENV LD_PRELOAD` and a modulefile `prepend-path LD_PRELOAD` are both silently
dropped. On top of that, `SPYGLASS_HOME/.spyglass.setup` ships
`OPTIMIZE_PERF = snpsmem`, which makes the wrapper append its own allocator,
`lib/libreplacemalloc.so`, to that preload list. That allocator is what exposes
the libudev bug as glibc's `mremap_chunk()` abort; the other ptmalloc-based one
behaves the same way (`libsgptmalloc-Linux4.so`, selected by
`OPTIMIZE_PERF = memory`, also aborts), while `libsgjemalloc-Linux4.so`
(`OPTIMIZE_PERF = runtime`) and plain glibc malloc happen to survive.

`spyglass/2025.06/Containerfile` therefore exports the system libudev through
the only variable the wrapper honours:

```dockerfile
ENV SPYGLASS_LD_PRELOAD=/lib64/libudev.so.1
```

The wrapper then appends its own allocator behind that entry, keeping libudev
first in symbol resolution and leaving the delivered memory manager enabled.
The `spyglass` modulefile in `synopsys/2025.06/` sets the same variable, since
that image copies the tree but not the product image's `ENV`. Verified with a
trivial `sg_shell -tcl` run and with a full `lint/lint_rtl` run on the demo UART
(`Design_Read` and `lint_rtl` both complete); without the variable both abort at
startup.
