# Formality container quirks

Two independent startup failures, hit in this order. Both fixes are applied in
the `Containerfile`; no wrapper `LD_PRELOAD` is needed.

## 1. Bundled `libk5crypto`

`fm_shell` died immediately with

```
symbol lookup error: /lib64/libkrb5.so.3: undefined symbol:
krb5int_c_deprecated_enctype, version k5crypto_3_MIT
```

FM's RPATH puts `.../shlib/export` ahead of `/lib64`, and that directory holds
an el7-era `libk5crypto.so.3`. `libkrb5`/`libgssapi_krb5` come from `runtime`'s
`krb5-libs` 1.18.2, which expects symbols the older bundled copy does not
export. Deleting the bundled copy lets the matching system `libk5crypto` be
used.

Only `libk5crypto.so.3*` is removed. `shlib/libcrypto.so.1.1` stays: it is not
in the shadowing `shlib/export` RPATH, it is used by the bundled Python/tcl
trees, and a blanket `-name 'libcrypto.so.1.1*' -delete` would break them.
`libssl.so.10` also stays for the GSSAPI consumer that needs that soname.

## 2. `libudev` on the FlexLM hostid enumeration

With the k5crypto fix applied, `fm_shell` still aborted with
`realloc(): invalid pointer` (`Error code=6`) while FlexLM built the hostid.

The tool enumerates `/sys` through libudev for the hostid, and inside a
container libudev and the SCL/FlexLM code shipped in the tool disagree about
symbol resolution: libudev gets its strings from one `strdup()`/`strndup()` and
hands them to a `realloc()` from another implementation. Preloading libudev
makes its own symbols resolve to its own copy again — the standard workaround
for FlexLM-based tools in containers (systemd issue #19733 for Quartus II, the
Revenera FlexNet Publisher forum for a vendor app, both with the same
backtrace):

```dockerfile
ENV LD_PRELOAD=/lib64/libudev.so.1
```

The crash only appears once a license server is configured (without one the
tool just reports `LCSH-5`), and it is not a `ValidationTool` artifact.
