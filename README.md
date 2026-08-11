# Kubedoll Heavy Industries — Helm Charts

Minimally-forked Helm charts with volume injection support for certificate-based database authentication.

## Charts

| Chart | Upstream | Fork Version | Changes |
|-------|----------|-------------|---------|
| `penpot` | [penpot/penpot-helm](https://github.com/penpot/penpot-helm) v0.38.0 | `0.38.0-khi.1` | Added `backend.initContainers` |
| `plane-ce` | [makeplane/plane](https://github.com/makeplane/plane) v1.4.1 | `1.4.1-khi.1` | Added `extraVolumes`, `extraVolumeMounts`, `initContainers` to api/worker/beatworker/migrator |
| `keycloak` | [bitnami/keycloak](https://github.com/bitnami/charts/tree/main/bitnami/keycloak) v25.2.0 | `25.2.0-kdhi.1` | Retargeted image default to [`ghcr.io/kubedoll-heavy-industries/kdhi-keycloak-image:0.1.0`](https://github.com/Kubedoll-Heavy-Industries/kdhi-keycloak-image) (custom SPIs: `dev.kdhi.keycloak.anonymous` + Phase Two `keycloak-events`). Upstream already exposed `extraVolumes`/`extraVolumeMounts`/`initContainers`/`extraEnvVars`/`externalDatabase` so no template changes were needed for CNPG cert auth. |
| `geodesa-app` | [bjw-s-labs/app-template](https://github.com/bjw-s-labs/helm-charts/tree/app-template-5.0.1/charts/other/app-template) v5.0.1 | `5.0.1-kdhi.1` | Renamed, license-preserving application chart used by the typed Haruspex `HelmApplication` component. |

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
helm install keycloak khi/keycloak
```

## Contributing upstream

These forks are intentionally minimal. The goal is to contribute these changes upstream and deprecate these forks once accepted.
