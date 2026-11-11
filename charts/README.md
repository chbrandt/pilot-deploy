# Charts

This directory contains Helm charts for HPC Pilot components.

## Production charts

### Pilot services — `manager/`

Deploys the **two HPC Pilot services** inside the Kubernetes cluster, along
with all supporting resources (RBAC, ConfigMaps, PVC, Ingress):

- **pilot-api** — the REST API server (pilot-api repository)
- **pilot-app** — the web GUI (pilot-app repository), a pure HTTP client of
  the API

- Chart: [`manager/`](./manager/)
- Full instructions: [`manager/README.md`](./manager/README.md)

Quick start:

```bash
API_SECRET=$(python -c 'import secrets; print(secrets.token_hex(32))')
APP_SECRET=$(python -c 'import secrets; print(secrets.token_hex(32))')

helm install pilot ./charts/manager \
  --set api.image.repository=ghcr.io/<your-org>/pilot-api \
  --set api.flask.secretKey="$API_SECRET" \
  --set app.image.repository=ghcr.io/<your-org>/pilot-app \
  --set app.flask.secretKey="$APP_SECRET" \
  --set siteConfig.hostname=pilot.example.org \
  --set interlinkConfig.chart=oci://ghcr.io/chbrandt/interlink-helm-chart/interlink
```

### InterLink Pod — `interlink/`

Defines the default values for the InterLink Helm chart that the manager
deploys automatically into each user's namespace via `POST /api/interlink`.
This chart is **not** installed directly by the operator — it is managed by
the pilot-api service on behalf of users.

- Values reference: [`interlink/values.yaml`](./interlink/values.yaml)
- Details: [`interlink/README.md`](./interlink/README.md)

---

## Development / example charts

| Directory | Purpose |
|---|---|
| `test_pods/` | Example pod/test manifests for validating the InterLink + wstunnel deployment without the manager |

---

## Deployment order

```
1. helm install manager ./charts/manager   # deploy the manager app
2. (users log in)                          # manager auto-creates user namespaces
3. POST /api/interlink                     # manager deploys InterLink per user
4. (HPC setup)                             # wstunnel client connects from edge-node
```

See [`documentation/deployment.md`](../documentation/deployment.md) for the
complete step-by-step guide.
