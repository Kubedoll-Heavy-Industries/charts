# Kubedoll Heavy Industries — Helm Charts

Minimally-forked Helm charts with volume injection support for certificate-based database authentication.

## Charts

| Chart | Upstream | Fork Version | Changes |
|-------|----------|-------------|---------|
| `penpot` | [penpot/penpot-helm](https://github.com/penpot/penpot-helm) v0.38.0 | `0.38.0-khi.1` | Added `backend.initContainers` |
| `plane-ce` | [makeplane/plane](https://github.com/makeplane/plane) v1.4.1 | `1.4.1-khi.1` | Added `extraVolumes`, `extraVolumeMounts`, `initContainers` to api/worker/beatworker/migrator |

## Why

Both upstream charts lack the ability to mount custom volumes and run init containers on their database-connected pods. This is required for CNPG certificate-based PostgreSQL authentication, where:

1. cert-manager provisions client certificates as Kubernetes Secrets
2. An init container copies certs and fixes permissions (`chmod 600` for JDBC)
3. The application container mounts the prepared certificates

## Usage

```bash
helm repo add khi https://kubedoll-heavy-industries.github.io/charts
helm install penpot khi/penpot
helm install plane khi/plane-ce
```

## Contributing upstream

These forks are intentionally minimal. The goal is to contribute these changes upstream and deprecate these forks once accepted.
