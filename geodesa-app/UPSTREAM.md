# Upstream provenance

`geodesa-app` is a minimally changed fork of
[`bjw-s-labs/helm-charts`](https://github.com/bjw-s-labs/helm-charts)
`app-template` 5.0.1.

- Source tag: `app-template-5.0.1`
- Source commit: `eea11eae60170b61485cc14314a6bf20f42c79e4`
- OCI artifact: `ghcr.io/bjw-s-labs/helm/app-template:5.0.1`
- OCI manifest digest: `sha256:70a7cb6766eb468068c2c1700c8450253070dc671a9fbbd1a6346a66545e2b2b`
- Downloaded chart archive SHA-256: `e99ebe581c41a38e1fa282bf53d4306b5cba01a27f89543583dc0817b8fa6558`
- Upstream license: Apache License 2.0, preserved in `LICENSE`

The fork changes chart identity and provenance metadata only. Templates,
values, schema, and license are preserved from upstream. `Chart.lock` and the
packaged Common 5.0.1 dependency are generated with `helm dependency build`.

Upstream declares `kubeVersion: ">=1.28.0-0"`. The fork is linted and
rendered against Kubernetes 1.36.2 by `tests/render_contract.rb`, which also
checks the concrete workload, security, migration, and Gateway API resources.
