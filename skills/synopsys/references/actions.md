# Submitting from Gitea Actions

A workflow submits the Job with `kubectl`; the tool image runs in the Job pod,
never in the workflow job pod.

- `runs-on: [ubuntu-latest, eda, cluster]` mounts the shared `ci-work` volume at
  `/work` and authenticates as `gitea/gitea-job`, which creates, updates and
  deletes Jobs in `synopsys`, reads their pods and logs and reads PodGroup
  status there, and has no access to other namespaces.
- `azure/setup-kubectl@v4` installs `kubectl` into `PATH`; runner images do not
  ship it.
- Check out the repository with `actions/checkout@v4`, copy it to
  `/work/<owner>/<repo>/<run_number>` and `chown -R 1001:1001` that directory.
- The tool Job mounts `ci-work` at `/work`, runs with `workingDir` there, and
  mounts the PDK read-only at `/pdks`.
- Keep each Job under the workflow's 3 hour timeout.
- The manifest is the same as in [jobs.md](jobs.md): `synopsys` namespace,
  `schedulerName: kai-scheduler`, user 1001, `ci-work` at `/work`, read-only
  `/pdks`.

```yaml
jobs:
  synthesis:
    runs-on: [ubuntu-latest, eda, cluster]
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-kubectl@v4

      - name: Stage the checkout on ci-work
        run: |
          set -eu
          RUN="/work/${GITHUB_REPOSITORY}/${GITHUB_RUN_NUMBER}"
          mkdir -p "$RUN"
          cp -a "$GITHUB_WORKSPACE"/. "$RUN"/
          chown -R 1001:1001 "$RUN"
          echo "RUN=$RUN" >> "$GITHUB_ENV"

      - name: Submit and wait
        run: |
          set -eu
          kubectl -n synopsys apply -f design/dc-job.yaml
          kubectl -n synopsys wait --for=condition=complete job/dc-counter --timeout=170m

      - name: Logs
        if: always()
        run: kubectl -n synopsys logs job/dc-counter --ignore-not-found

      - name: Delete the Job
        if: always()
        run: kubectl -n synopsys delete job/dc-counter --ignore-not-found
```

`design/dc-job.yaml` uses `${RUN}` as `workingDir` and mounts `ci-work` at
`/work`. [../examples/actions-job.yaml](../examples/actions-job.yaml) is a full
workflow with the manifest inline.

## Outputs

A second Job in `synopsys` uploads the results from the shared `ci-work` volume,
so the copy runs after the tool pod exits. Both Jobs mount the volume at
`/work`; the tool pod can also upload directly because it has network.

The upload Job reads bucket credentials from a Secret in `synopsys` that
already exists and whose name the workflow passes in; the Secret holds
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `S3_BUCKET`.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: dc-upload
  namespace: synopsys
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: upload
          image: amazon/aws-cli:2.39.4
          envFrom:
            - secretRef:
                name: <s3-secret>
          env:
            - name: S3_ENDPOINT
              value: http://seaweedfs-s3.seaweedfs.svc.cluster.local:8333
            - name: RUN_DIR
              value: /work/<owner>/<repo>/<run_number>
            - name: S3_PREFIX
              value: <owner>/<repo>/<run_number>
          command: ["sh", "-c"]
          args:
            - |
              set -eu
              aws --endpoint-url "$S3_ENDPOINT" s3 cp "$RUN_DIR" \
                "s3://${S3_BUCKET}/${S3_PREFIX}/" --recursive
              rm -rf "$RUN_DIR"
          volumeMounts:
            - name: work
              mountPath: /work
      volumes:
        - name: work
          persistentVolumeClaim:
            claimName: ci-work
```

The upload Job deletes the run directory after a successful copy.
[../examples/actions-job.yaml](../examples/actions-job.yaml) shows the whole
run: both Jobs, logs and cleanup.
