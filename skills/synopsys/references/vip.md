# VIP

`local.io/synopsys/vip:2023.12` is a read-only file image holding the VIP tree
that VCS/UVM compiles against. It has no entry point and no license file. Mount
it at `/opt/designware` and set `DESIGNWARE_HOME` to that path:

```yaml
spec:
  containers:
    - name: vcs
      image: local.io/synopsys/vcs:2025.06-SP1
      env:
        - { name: DESIGNWARE_HOME, value: /opt/designware }
      volumeMounts:
        - { name: vip, mountPath: /opt/designware, readOnly: true }
  volumes:
    - name: vip
      image:
        reference: local.io/synopsys/vip:2023.12
        pullPolicy: IfNotPresent
```

Do not mount it at any path other than `DESIGNWARE_HOME`: the image root is the
`DESIGNWARE_HOME` tree.

## Contents

The image installs three packages from the V-2023.12 delivery into one tree:

| Package | Why |
| --- | --- |
| `vip_library19_svt` | `vip/common`, `vip/svt/common` and every SVT product's `sverilog/src/vcs/*.svp`; includes the `bin/` setup tools |
| `vip_ecpri_svt` | the only SVT product not bundled in `library19` |
| `vip_memory_svt` | the other SVT product not bundled in `library19` |

The installed tree holds all 59 compile VIP product trees from the delivery
(svt, svc, nvs and ocp_vrt). Per-product `doc/` trees, `vip_smartsearch` and
`vip_vipcc` are not included.

## Use

- The `bin/dw_vip_setup` helper is a Perl script. Use the VCS image, which
  carries `perl`; compiling VIP files through `-ntb_opts` / filelists does not
  need the helper.
- The vendor AHB SVT UVM example is exercised by the repository's
  `vip/2023.12/k8s/vip-vcs-smoke.yaml`; apply it in `synopsys` and read
  `job/vip-vcs-smoke`. The expected final line is `VIP_SMOKE_PASS`.
- The delivery is V-2023.12 while the current VCS image is X-2025.06-SP1.
  Smoke-test one protocol (for example AMBA/AXI) with the target VCS before
  relying on the pair. If the tools reject the version, build a VIP release
  from the same generation as VCS.
- A running VIP still checks out its feature from the site license server
  ([licenses.md](licenses.md)).
