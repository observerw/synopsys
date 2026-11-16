# Jobs

Manifest fields:

- Namespace `synopsys`; apply with `kubectl -n synopsys apply -f job.yaml` from a
  workspace or a Gitea Actions workflow ([actions.md](actions.md)).
- Set `schedulerName: kai-scheduler` in the Pod template.
- Set `workingDir` under `/data2/<user>/<project>` and mount `/data2` at
  `/data2`, so results outlive the pod and stay visible to the workspace.
- Mount the selected PDK root read-only at `/pdks` ([pdks.md](pdks.md)).
- Set `securityContext: {runAsUser: 1001, runAsGroup: 1001, supplementalGroups: [1003]}`
  so the outputs stay owned by your workspace user.
- Set `resources.requests.cpu` and `memory`; EDA jobs need no GPU.
- Set both license variables in `env` ([licenses.md](licenses.md)).
- Pods have ordinary cluster network access; stage inputs under `/data2` so a
  run does not depend on downloads.

A minimal Job is in [../examples/pt-job.yaml](../examples/pt-job.yaml); the
Design Compiler examples add PDK-specific `run.tcl` files.

## KAI Scheduler

- KAI is installed in the `kai-scheduler` namespace; no per-namespace LocalQueue
  is needed.
- Leave the queue label unset to use the default queue `default-queue`.
- Request CPU and memory only.
- Without `schedulerName: kai-scheduler` the default `kube-scheduler` runs the
  Job and KAI is bypassed.
- Check: `kubectl -n synopsys get podgroups`; PodGroup status explains why a Job
  is not schedulable.

## Operate

```bash
kubectl -n synopsys get job,pod,podgroup
kubectl -n synopsys logs -f job/<name>
kubectl -n synopsys describe pod <pod>
kubectl -n synopsys delete job <name>
```

Set `backoffLimit: 0` for tool runs so a failed tool script is not retried.
