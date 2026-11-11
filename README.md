# Pilot Deploy

Deployment recipes for [HPC Pilot](https://github.com/chbrandt): the Helm
charts and the docker recipes used to run the `pilot-*` services.

HPC Pilot itself is split into three repositories:

| Repository | Role |
|---|---|
| [pilot-api](https://github.com/chbrandt/pilot-api) | REST API server — Kubernetes/Helm/HPC/EGI Check-in logic |
| [pilot-app](https://github.com/chbrandt/pilot-app) | Web GUI — a pure HTTP client of the API |
| **pilot-deploy** (this repo) | Helm charts, docker compose recipes, CI packaging |

## Repository layout

```
.
├── charts/
│   ├── manager/          # Helm chart: deploys pilot-api + pilot-app (two-service)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/   # namespace, RBAC, ConfigMap, Secret, Deployments,
│   │                    # Services, Ingress, PVC
│   ├── interlink/       # default values for the per-user InterLink chart
│   │                    # (installed by pilot-api on behalf of users)
│   └── test_pods/       # sample pod manifests for testing
├── docker/
│   ├── motley_cue/      # Dockerfile + config recipe for the HPC edge-node
│                        # motley-cue (OIDC-authenticated SSH) service
│   └── docker-compose.yml # local full-stack recipe (pilot-api + pilot-app)
└── .github/workflows/   # CI: helm lint (pr) / helm package (release, test)
```

## Quick start (in-cluster)

```bash
API_SECRET=$(python -c 'import secrets; print(secrets.token_hex(32))')
APP_SECRET=$(python -c 'import secrets; print(secrets.token_hex(32))')

helm install pilot ./charts/manager \
  --set api.image.repository=ghcr.io/chbrandt/pilot-api \
  --set api.image.tag=latest \
  --set api.flask.secretKey="$API_SECRET" \
  --set app.image.repository=ghcr.io/chbrandt/pilot-app \
  --set app.image.tag=latest \
  --set app.flask.secretKey="$APP_SECRET" \
  --set siteConfig.hostname=pilot.example.org
```

This creates (see [`charts/manager/README.md`](charts/manager/README.md)):

- a `Namespace` (`hpc-pilot`) with a `ServiceAccount` + `ClusterRoleBinding`
  (pilot-api needs cluster-wide permissions to manage per-user namespaces
  and install the InterLink releases),
- a `ConfigMap` with the unified `pilot_config.yaml`
  (site/charts/hpc configuration),
- **Deployments** for `pilot-api` and `pilot-app` (each with its own
  `Service`; the GUI is wired to the API through `API_BASE_URL`),
- an **Ingress** on `siteConfig.hostname` that routes `/` to the GUI and
  `/api` (incl. the Swagger UI at `/api/docs`) to the API,
- the **Ingress routes** for each user's wstunnel (path-prefix based, no
  wildcard certificate needed — see the chart README for the full picture).

## Quick start (docker compose)

```bash
docker compose -f docker/docker-compose.yml up
# GUI → http://localhost:5001      API → http://localhost:5000 (Swagger: /api/docs)
```

## Chart values

The full values reference lives in
[`charts/manager/values.yaml`](charts/manager/values.yaml) and
[`charts/manager/README.md`](charts/manager/README.md). Headline values:

| Value | Purpose |
|---|---|
| `api.image.*` / `app.image.*` | The two service images |
| `api.flask.secretKey` / `app.flask.secretKey` | Session keys (always override in production) |
| `api.oidcClientSecret` | `PILOT_OIDC_CLIENT_SECRET` for the API (confidential EGI Check-in clients) |
| `siteConfig.hostname` | Single shared hostname (no wildcard DNS/TLS needed) |
| `siteConfig.wstunnel.port` / `localPort` | Shared wstunnel routing ports |
| `hpcConfig.nodes` | Per-HPC-node connection details (`hostname`, `ssh_port`, `plugin`) |
| `interlinkConfig.chart` | The InterLink chart reference installed per user |

## Continuous Integration

- `pr.yml` — `helm lint` + `helm template` validation for pull requests
- `release.yml` — packages the chart (versioned from the release tag) and
  attaches it to the GitHub release
- `test-branch.yml` — lints and packages the chart on the `test` branch,
  uploading it as a workflow artifact

(Docker images are built and pushed by the `pilot-api` and `pilot-app`
repositories' own workflows — each service carries its Dockerfile next to
its source.)
