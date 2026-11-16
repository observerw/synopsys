# Library Compiler container quirks

## Bundled OpenSSL: `libk5crypto` and `libcrypto.so.1.1`

LC ships an el7-era `libk5crypto.so.3` next to its own `libcrypto.so.1.1`
builds. Its RPATH puts the bundled directory ahead of `/lib64`, so `libkrb5`
from `runtime`'s `krb5-libs` 1.18.2 found the old `libk5crypto` and failed with

```
/lib64/libkrb5.so.3: undefined symbol: krb5int_c_deprecated_enctype,
version k5crypto_3_MIT
```

`lc/2025.06/Containerfile` deletes both `libk5crypto.so.3*` and all
`libcrypto.so.1.1*` copies, and lets `runtime`'s `openssl-libs` provide that
soname: LC only needs the system OpenSSL 1.1, and its bundled 1.1 copies are
not used once the k5crypto switch is made. `libssl.so.10` stays, because
nothing else provides that el7 soname.

Other products remove a different subset on purpose — a blanket
`find ... -name 'libcrypto.so.1.1*' -delete` would delete copies their bundled
Python/tcl trees still use. Re-audit with a `find` for `libk5crypto.so.3*`,
`libcrypto.so.1.1*` and `libssl.so.10*` in the finished image when a new
release changes its bundled OpenSSL.

## License checkout crashes in libudev

`lc_shell` used to die right after `Initializing...` as soon as a license server
was configured, with a mix of `realloc(): invalid pointer` and a SIGSEGV
(`Error code=6` / `11`), tracing through
`udev_enumerate_scan_devices` → `sd_device_new_from_syspath` →
`chase_symlinks` → `strextend_with_separator` → `realloc`.

The tool builds the hostid for the checkout by enumerating `/sys` through
libudev, and inside a container libudev and the SCL/FlexLM code that ships in
the tool disagree about symbol resolution: libudev gets its strings from one
`strdup()`/`strndup()` and then hands them to a `realloc()` from another
implementation. Preloading libudev makes its own symbols resolve to its own
copy again, which is the standard workaround for FlexLM-based tools in
containers (systemd issue #19733 for Quartus II, the Revenera FlexNet Publisher
forum for a vendor app, both with the same backtrace):

```dockerfile
ENV LD_PRELOAD=/lib64/libudev.so.1
```

Two properties of the failure are worth remembering when looking at another
product: it only appears once a license server is configured (without one the
tool just reports `LCSH-5`), and it is not a `ValidationTool` artifact —
the identical stack is reported for unpatched Quartus II and for FlexNet
Publisher applications running in Docker.
