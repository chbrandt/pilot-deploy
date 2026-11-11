# HPC Pilot — Helm Chart (pilot-deploy)

This chart deploys the **two HPC Pilot services** inside a Kubernetes
cluster, together with all the supporting resources they need to manage
per-user [InterLink](https://interlink-project.dev) pod deployments:

- **pilot-api** — the REST API server
  ([pilot-api](https://github.com/chbrandt/pilot-api)); talks to Kubernetes,
  Helm and the HPC edge-nodes. Owns the RBAC ServiceAccount, the
  `pilot_config.yaml` ConfigMap and (optionally) the data PVC.
- **pilot-app** — the web GUI ([pilot-app](https://github.com/chbrandt/pilot-app));
  a pure HTTP client of the API. Reached by users through the Ingress.

- **Chart name:** `egi-hpc-pilot` (see [`Chart.yaml`](./Chart.yaml))
- **Version:** `0.3.0` / appVersion `0.4.1`

---

## Overview

### What this chart creates

| Resource | Kind | Purpose |
|---|---|---|
| `hpc-pilot` | `Namespace` | Dedicated namespace for the manager |
| `hpc-pilot-manager` | `ServiceAccount` | In-cluster identity for the pod |
| `egi-hpc-pilot` | `ClusterRole` | RBAC superset of the InterLink virtual-kubelet role: namespaces, jobs, services, ingresses, nodes (+status), pods (+status), configmaps, secrets, events, deployments, replicasets, serviceaccounts (+token), certificatesigningrequests (+approval), leases, and cluster/role RBAC |
| `egi-hpc-pilot` | `ClusterRoleBinding` | Binds the ClusterRole to the ServiceAccount |
| `<fullname>` | `Secret` | Session keys for both services (+ optional OIDC client secret) |
| `<fullname>-pilot-config` | `ConfigMap` | `pilot_config.yaml` (unified site + charts + hpc configuration) |
| `<fullname>-data` | `PersistentVolumeClaim` | Durable store for per-user saved deployment configs (pilot-api) |
| `<fullname>-api` | `Deployment` | The **pilot-api** pod |
| `<fullname>-app` | `Deployment` | The **pilot-app** (web GUI) pod |
| `<fullname>-api` | `Service` | ClusterIP (port 80 → Flask port 5000) |
| `<fullname>-app` | `Service` | ClusterIP (port 80 → Flask port 5000) |
| `<fullname>` | `Ingress` | nginx Ingress on `siteConfig.hostname`: `/` → `pilot-app`, `/api` → `pilot-api` |

---

## Prerequisites

- Kubernetes ≥ 1.24
- Helm v3
- An **nginx Ingress controller** installed in the cluster
- A **DNS record** for the single `siteConfig.hostname` pointing at the Ingress
  controller's external IP (no wildcard record required — routing is
  path-prefix based)
- The two container images built and pushed to an accessible registry:
  `pilot-api` (from the pilot-api repository) and `pilot-app` (from the
  pilot-app repository)

---

## Building the images

```bash
# pilot-api (from the pilot-api repository root)
docker build -t ghcr.io/<your-org>/pilot-api:latest .
docker push ghcr.io/<your-org>/pilot-api:latest

# pilot-app (from the pilot-app repository root)
docker build -t ghcr.io/<your-org>/pilot-app:latest .
docker push ghcr.io/<your-org>/pilot-app:latest
```

---

## Quick start

```bash
# 1. Generate strong Flask secret keys (one per service)
API_SECRET=$(python -c 'import secrets; print(secrets.token_hex(32))')
APP_SECRET=$(python -c 'import secrets; print(secrets.token_hex(32))')

# 2. Install the chart
helm install pilot ./charts/manager \
  --set api.image.repository=ghcr.io/<your-org>/pilot-api \
  --set api.image.tag=latest \
  --set api.flask.secretKey="$API_SECRET" \
  --set app.image.repository=ghcr.io/<your-org>/pilot-app \
  --set app.image.tag=latest \
  --set app.flask.secretKey="$APP_SECRET" \
  --set siteConfig.hostname=pilot.example.org \
  --set interlinkConfig.chart=oci://ghcr.io/chbrandt/interlink-helm-chart/interlink

# 3. Verify
kubectl get all -n hpc-pilot
kubectl get ingress -n hpc-pilot
```

---

## Configuration reference

### Images

Identical structure under `api.` (the REST API) and `app.` (the web GUI):

| Parameter | Default | Description |
|---|---|---|
| `api.image.repository` | `ghcr.io/chbrandt/pilot-api` | pilot-api image repository |
| `app.image.repository` | `ghcr.io/chbrandt/pilot-app` | pilot-app image repository |
| `api.image.tag` / `app.image.tag` | `latest` | Image tags |
| `api.image.pullPolicy` / `app.image.pullPolicy` | `Always` | Image pull policy |
| `api.image.pullSecrets` / `app.image.pullSecrets` | `[]` | Optional registry pull secrets |
| `api.replicaCount` / `app.replicaCount` | `1` | Number of pods per service |

### Flask

| Parameter | Default | Description |
|---|---|---|
| `api.flask.port` / `app.flask.port` | `5000` | Port Flask listens on inside the container |
| `api.flask.debug` / `app.flask.debug` | `"0"` | Set to `"1"` for debug mode (never in production) |
| `api.flask.secretKey` / `app.flask.secretKey` | `"ok-for-dev-only-…"` | Flask session secret keys — **always override in production** |
| `api.flask.existingSecret` / `app.flask.existingSecret` | `""` | Use a pre-existing Secret instead of creating one |
| `api.flask.existingSecretKey` | `flask-secret-key` | Key inside the existing Secret (pilot-api) |
| `app.flask.existingSecretKey` | `app-flask-secret-key` | Key inside the existing Secret (pilot-app) |
| `app.apiBaseUrl` | `""` | Base URL of the API as seen from the GUI pod (default: the in-cluster `…-api` Service) |

### OIDC client secret (pilot-api only)

| Parameter | Default | Description |
|---|---|---|
| `api.oidcClientSecret` | `""` | Chart-Secret value injected as `PILOT_OIDC_CLIENT_SECRET` into the API pod — the GUI never receives it |
| `api.existingOidcSecret` | `""` | Use a pre-existing Secret for the OIDC client secret |
| `api.existingOidcSecretKey` | `pilot-oidc-client-secret` | Key inside the existing OIDC Secret |

### Unified configuration (`pilot_config.yaml`)

The chart writes a single `pilot_config.yaml` ConfigMap (rendered by
[`templates/configmap-pilot.yaml`](./templates/configmap-pilot.yaml)) with
three sections — `site`, `charts` and `hpc` — built from the `siteConfig`,
`interlinkConfig` and `hpcConfig` values below.

#### Site configuration

| Parameter | Default | Description |
|---|---|---|
| `siteConfig.hostname` | `app.hpc-pilot.test.fedcloud.eu` | Single fixed hostname for the manager and every user's InterLink wstunnel endpoint (path-prefix routing — no wildcard DNS) |
| `siteConfig.defaultImage` | `ubuntu:22.04` | Default container image proposed in the Submit Job form |
| `siteConfig.wstunnel.port` | `80` | Port the wstunnel ingress listens on |
| `siteConfig.wstunnel.localPort` | `4000` | Local port on the HPC edge-node wstunnel forwards to |
| `siteConfig.allowedGroups` | `[]` | Optional list of EGI VO entitlement substrings restricting access (empty = open) |

> Without `siteConfig.wstunnel.*` the HPC endpoints would raise a
> `KeyError`, so always supply them.

#### HPC node connection details

| Parameter | Default | Description |
|---|---|---|
| `hpcConfig.nodes` | `{}` | Map of `<hpc_name>: {hostname, ssh_port, plugin}` — one entry per HPC target |

```yaml
hpcConfig:
  nodes:
    test-echo:
      hostname: 161.9.255.206
      ssh_port: 22
      plugin: echo
```

#### InterLink chart defaults

| Parameter | Default | Description |
|---|---|---|
| `interlinkConfig.chart` | `oci://ghcr.io/chbrandt/interlink` | InterLink chart reference (OCI / repo / URL) |
| `interlinkConfig.version` | `null` | Pin a chart version, or `null` for latest |
| `interlinkConfig.interlink.address` | `http://0.0.0.0` | InterLink API server bind address |
| `interlinkConfig.interlink.port` | `3000` | InterLink API server port |
| `interlinkConfig.virtualNode.disableCSR` | `true` | Do not request a cluster-signed kubelet serving cert via a CSR; the virtual-kubelet serves `:10250` with a self-signed cert (requires apiserver `--kubelet-insecure-tls`) |
| `interlinkConfig.plugin.address` | `http://0.0.0.0` | Plugin bind address (HPC side) |
| `interlinkConfig.plugin.port` | `4000` | Plugin port |
| `interlinkConfig.wstunnel.port` | `8080` | wstunnel server port inside the pod |
| `interlinkConfig.wstunnel.logLevel` | `debug` | wstunnel log level |

The wstunnel **ingress host**, **external port**, **internal port** and
**secret** are deliberately not configurable here — they are derived from
`siteConfig.hostname`, `siteConfig.wstunnel.port`,
`siteConfig.wstunnel.localPort` and the per-user namespace, so every user's
tunnel stays consistent with the site-level routing configuration.

Placeholder tokens resolved per-user at seed time (only these two are used):

| Token | Replaced with |
|---|---|
| `__NAMESPACE__` | User's Kubernetes namespace, e.g. `user-a3f1b2c4d5e6f7a8` |
| `__HOSTNAME__` | `siteConfig.hostname` (the single shared hostname) |

### Persistence (pilot-api)

The saved-configuration store lives in the API pod (`/app/data`), so the PVC
belongs to pilot-api:

| Parameter | Default | Description |
|---|---|---|
| `api.persistence.enabled` | `false` | Mount a PVC for `/app/data` |
| `api.persistence.size` | `1Gi` | PVC storage size |
| `api.persistence.accessMode` | `ReadWriteOnce` | PVC access mode |
| `api.persistence.storageClass` | `""` | StorageClass (leave blank for cluster default) |
| `api.persistence.existingClaim` | `""` | Use a pre-existing PVC |

### Ingress

| Parameter | Default | Description |
|---|---|---|
| `ingress.enabled` | `true` | Create an Ingress resource |
| `ingress.className` | `nginx` | IngressClass name |
| `ingress.pathType` | `Prefix` | Path type (`/` → `pilot-app`, `/api` → `pilot-api`) |
| `ingress.port` | `80` | Backend service port |
| `ingress.annotations` | see values | Extra annotations (timeouts are pre-configured) |
| `ingress.tls.enabled` | `true` | Enable TLS for `siteConfig.hostname` |
| `ingress.tls.secretName` | `pilot-tls` | Secret holding the TLS certificate |

> The Ingress host is `siteConfig.hostname` (not a separate `ingress.host`
> value). The chart does **not** require a wildcard record — a single-host
> TLS certificate is sufficient.

### Resources

| Parameter | Default |
|---|---|
| `api.resources.requests.cpu` | `100m` |
| `api.resources.requests.memory` | `128Mi` |
| `api.resources.limits.cpu` | `500m` |
| `api.resources.limits.memory` | `512Mi` |
| `app.resources.requests.cpu` | `50m` |
| `app.resources.requests.memory` | `64Mi` |
| `app.resources.limits.cpu` | `250m` |
| `app.resources.limits.memory` | `256Mi` |

---


## How pilot-api connects to InterLink deployments

```
User logs in (EGI Check-in token)
  │
  ▼
Manager (pilot-api) derives namespace: user-<hash>   ←── from token "sub" claim
  │
  ▼
POST /api/interlink
  │   helm install interlink-<hpc_name> oci://ghcr.io/chbrandt/interlink \
  │     --namespace user-<hash> \
  │     --values -   (wstunnel.ingress.host = siteConfig.hostname, secret = __NAMESPACE__)
  │
  ▼
InterLink pod created in user-<hash> namespace:
  ├── virtual-kubelet node: vk-node-<hash>-<hpc_name>
  ├── interLink API server container  (port 3000)
  ├── wstunnel server container       (port 8080)
  └── nginx Ingress:  <hostname>/<namespace>  →  wstunnel:8080   (path-prefix)
  │
  ▼
HPC edge-node runs wstunnel client:
  wstunnel client \
    --http-upgrade-path-prefix 'user-<hash>' \
    -R 'tcp://4000:localhost:4000' \
    ws://<hostname>:80
```

> **No wildcard DNS required.** A single DNS record for `siteConfig.hostname`
> pointing at the nginx Ingress controller's external IP is enough — each
> user's wstunnel is disambiguated by the path prefix.

---

## Upgrading

```bash
helm upgrade pilot ./charts/manager \
  --reuse-values \
  --set api.image.tag=<new-api-tag> \
  --set app.image.tag=<new-app-tag>
```

## Uninstalling

```bash
helm uninstall manager
kubectl delete namespace hpc-pilot   # also removes user namespaces if desired
```

