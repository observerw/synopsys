# License

| Item | Value |
| --- | --- |
| Server | `synopsys/license` ClusterIP |
| Ports | `2700` lmgrd, `2701` snpslmd |
| Alias | `synopsys/lic1` selects the same pods; the vendor license's `SERVER` line reads `lic1` |
| Seats | every feature reports 99, so concurrency is limited by CPU and memory quota |

## Client environment

| Variable | Inside `synopsys` | Other namespace or workspace container |
| --- | --- | --- |
| `SNPSLMD_LICENSE_FILE` | `2700@license` | `2700@license.synopsys` |
| `LM_LICENSE_FILE` | `2700@license` | `2700@license.synopsys` |

- Set both variables in the Job `env`; images carry no license server address.
- Set both to the same value: tools read `SNPSLMD_LICENSE_FILE` first and fall
  back to `LM_LICENSE_FILE`.
- The value is `port@host`; both variables also accept a license file path or a
  colon-separated server list.
- License checkout is TCP `2700`-`2701` to `license`; the pod otherwise has
  ordinary cluster network access.

```yaml
env:
  - name: SNPSLMD_LICENSE_FILE
    value: 2700@license
  - name: LM_LICENSE_FILE
    value: 2700@license
```

## Check seats

```bash
kubectl -n synopsys exec deploy/license -- \
  lmutil lmstat -c 2700@127.0.0.1 -a
```

## License server image

`local.io/synopsys/scl:2025.03` is the FlexLM server. The license is node-locked
to MAC `52:54:00:ad:a0:86`, so the entrypoint rewrites `eth0`'s MAC and the pod
needs `NET_ADMIN`. The cluster manifest is
[`scl/2025.03/k8s/scl-lic.yaml`](../../../scl/2025.03/k8s/scl-lic.yaml).
