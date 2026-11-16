# Fusion Compiler container quirks

## 1. Two bundled crypto generations

`dgcom_exec` puts `shlib/export` and `shlib/qt/export` ahead of `/lib64` in its
RPATH, and both directories ship an el7-era `libk5crypto.so.3`, so `fc_shell`
died with the same

```
/lib64/libkrb5.so.3: undefined symbol: krb5int_c_deprecated_enctype,
version k5crypto_3_MIT
```

as `pt`/`fm`/`lc`. Deleting the bundled copy is necessary but not sufficient
here: `shlib/libcrypto.so.1.1` and `shlib_python/libcrypto.so.1.1` are Synopsys
builds of OpenSSL 1.1.1l/1.1.1t that export no `EVP_KDF_ctrl` at all, so once
the el8 `libk5crypto.so.3` is used the next start fails with

```
/lib64/libk5crypto.so.3: undefined symbol: EVP_KDF_ctrl,
version OPENSSL_1_1_1b
```

`fc/2025.06/Containerfile` therefore also removes those two bundled
`libcrypto.so.1.1` copies and lets `runtime`'s `openssl-libs` provide that
soname. The other copies stay on purpose: `etc/Python/lib/libcrypto.so.1.1`
and `etc/twkPython/lib/libcrypto.so.1.1` belong to the bundled Python trees,
only the `shlib*` copies are the ones `dgcom_exec` loads. `libssl.so.10` /
`libcrypto.so.10` stay: `libarrow.so.16`, `libparquet.so.16` and
`librdkafka*.so.1` need the el7 soname.

## 2. License checkout crashes in libudev

Those fixes get the tool through startup but not through its license checkout:
with a license server configured, `fc_shell` then aborts with

```
realloc(): invalid pointer
...
Fatal: Internal system error, cannot recover.
Error code=6
```

and a stack of `lc_checkout` → `udev_hwdb_get_properties_list_entry`, i.e. the
same libudev/FlexLM bug as `lc`/`pt`/`fm`: the hostid is built by enumerating
`/sys` through libudev, and libudev's `strdup()`-allocated strings end up in a
`realloc()` from another implementation. `fc/2025.06/Containerfile` sets

```dockerfile
ENV LD_PRELOAD=/lib64/libudev.so.1
```

and the `fc` modulefile in `synopsys/2025.06/` prepends the same, so
`module load fc` alone is enough. Without a license server the tool only
reports the usual checkout error and the crash does not show up.

## 3. `install_fc` post-install hook

The installer's `admin/install/FC/bin/install_fc` hook is a `#!/bin/csh -f`
script that only creates the optional `lc_shell` and Milkyway symlinks; the
build stage's `tcsh` is enough, and the tree is gated instead of the exit code.
