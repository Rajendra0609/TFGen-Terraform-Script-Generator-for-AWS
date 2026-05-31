# TFGen – Kubernetes Deployment Guide

## Architecture Overview

```
Internet
   │
   ▼
┌─────────────────────────────────────────────────────────────────┐
│  Ingress (nginx)  – tfgen.example.com                           │
│   /ws    → tfgen-backend:4000   (WebSocket / terraform-ls LSP) │
│   /api/* → tfgen-backend:4000   (REST API)                      │
│   /*     → tfgen-frontend:80    (React SPA via nginx)           │
└─────────────────────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
  ┌─────────────┐            ┌──────────────┐
  │  Backend    │            │  Frontend    │
  │  Deployment │            │  Deployment  │
  │  (2–6 pods) │            │  (2–4 pods)  │
  │  Node.js    │            │  nginx:alpine│
  │  port 4000  │            │  port 80     │
  └──────┬──────┘            └──────────────┘
         │  ↕ /var/run/docker.sock (HostPath)
         │  (checkov / infracost runs)
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│Postgres│ │ Redis  │
│  SS    │ │  SS    │
│ (1 pod)│ │ (1 pod)│
│ 10 Gi  │ │  5 Gi  │
└────────┘ └────────┘
```

## Files

| File | Purpose |
|------|---------|
| `00-namespace.yaml` | `tfgen` namespace |
| `01-configmap.yaml` | Non-sensitive runtime config (incl. SMTP_HOST/PORT/SECURE, FRONTEND_URL) |
| `02-secret.yaml` | DB creds, JWT secrets, ENCRYPT_KEY, **SMTP_USER/PASS/FROM**, FRONTEND_URL |
| `03-postgres-statefulset.yaml` | PostgreSQL StatefulSet using `daggu1997/tfgen_postgres:v0.0.1` |
| `04-redis-statefulset.yaml` | Redis 7 StatefulSet + Services + 5 Gi PVC |
| `05-db-init-job.yaml` | One-shot Job with **actual schema.sql + seed.sql** embedded |
| `06-backend-deployment.yaml` | Node.js/Express — `daggu1997/tfgen_backend:v0.0.1`, docker.sock mount, SMTP env |
| `07-frontend-deployment.yaml` | nginx/React — `daggu1997/tfgen_frontend:v0.0.1` |
| `08-ingress.yaml` | nginx Ingress with `/ws` WebSocket path + `/api` + SPA fallback |
| `09-hpa.yaml` | HPA for backend (2–6) and frontend (2–4) |

---

## What Changed From the Original Manifests

| File | Change | Reason |
|------|--------|--------|
| `01-configmap.yaml` | Added `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `FRONTEND_URL` | `mailer.js` reads these at runtime for email sending |
| `02-secret.yaml` | Added `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`, `FRONTEND_URL` | Sensitive credentials needed by nodemailer |
| `03-postgres-statefulset.yaml` | Changed image from `postgres:15` → `daggu1997/tfgen_postgres:v0.0.1` | Your custom image pre-loads schema/seed via initdb scripts |
| `05-db-init-job.yaml` | Embedded actual `schema.sql` and `seed.sql` content | Placeholders replaced with real SQL — Job is now runnable |
| `06-backend-deployment.yaml` | Changed image from placeholder → `daggu1997/tfgen_backend:v0.0.1` | Use the verified working Docker Hub image |
| `06-backend-deployment.yaml` | Added `/var/run/docker.sock` HostPath volume mount | `checkov.js` and `infracost.js` run `docker run ...` commands |
| `06-backend-deployment.yaml` | Added SMTP + FRONTEND_URL env vars from Secret | `mailer.js` needs these to send password-reset / notification emails |
| `07-frontend-deployment.yaml` | Changed image from placeholder → `daggu1997/tfgen_frontend:v0.0.1` | Use the verified working Docker Hub image |
| `08-ingress.yaml` | Added `/ws` path to backend + WebSocket headers ConfigMap | `terraform-ls` LSP uses WebSocket on the same port 4000 |

---

## Pre-Deployment Checklist

### 1. Secrets — update before any production deploy

Open `02-secret.yaml` and replace the default values with strong secrets:

```bash
# Generate strong secrets
openssl rand -hex 32   # for JWT_SECRET, JWT_REFRESH_SECRET, ENCRYPT_KEY

# Base64-encode any value
echo -n 'your_value' | base64 -w 0

# One-liner: generate + encode
echo -n "$(openssl rand -hex 32)" | base64
```

| Key | Current value | Action |
|-----|--------------|--------|
| `POSTGRES_PASSWORD` | `tfgen123` | **Change to a strong password** |
| `JWT_SECRET` | same as REFRESH | **Generate unique value** |
| `JWT_REFRESH_SECRET` | same as ACCESS | **Generate unique value** |
| `ENCRYPT_KEY` | from .env | Keep unless rotating (invalidates stored AWS creds) |
| `SMTP_USER` | Gmail address | Update to your actual Gmail |
| `SMTP_PASS` | 16-char app password | Update to your Gmail app password |
| `SMTP_FROM` | display name + email | Update to match your account |

### 2. Update Ingress hostname

In `08-ingress.yaml` and `01-configmap.yaml`, replace every occurrence of
`tfgen.example.com` with your actual domain or LoadBalancer IP.

### 3. Frontend API URL

The pre-built `daggu1997/tfgen_frontend:v0.0.1` image has `REACT_APP_API_URL`
baked in as `http://13.232.187.242:4000`. If your cluster Ingress address is
different, rebuild the frontend:

```bash
docker build \
  --build-arg REACT_APP_API_URL=http://YOUR_INGRESS_IP_OR_DOMAIN \
  --build-arg REACT_APP_API_URL_LS=http://YOUR_INGRESS_IP_OR_DOMAIN \
  --build-arg REACT_APP_APP_VERSION=v0.0.1 \
  --build-arg REACT_APP_APP_ENV=production \
  -t your-registry/tfgen-frontend:v0.0.1 \
  ./frontend
docker push your-registry/tfgen-frontend:v0.0.1
```
Then update `image:` in `07-frontend-deployment.yaml`.

### 4. Docker socket on worker nodes

The backend mounts `/var/run/docker.sock` from each K8s worker node.
Ensure Docker is installed and running on your nodes. On managed clusters
(EKS, GKE, AKS) the socket is available; on k3s/microk8s it may be at a
different path — update the `hostPath` in `06-backend-deployment.yaml`.

### 5. StorageClass (for PVCs)

The Postgres and Redis StatefulSets request PVCs with no `storageClassName`
(uses cluster default). If your cluster has no default StorageClass, uncomment
and set the class explicitly:
- AWS EKS: `gp3`
- GKE: `standard`
- minikube/k3s: `standard`

---

## Deployment Steps

```bash
# 1. Namespace first
kubectl apply -f 00-namespace.yaml

# 2. Config and Secrets
kubectl apply -f 01-configmap.yaml
kubectl apply -f 02-secret.yaml

# 3. Database layer (Postgres + Redis)
kubectl apply -f 03-postgres-statefulset.yaml
kubectl apply -f 04-redis-statefulset.yaml

# 4. Wait for PostgreSQL to complete initdb
kubectl rollout status statefulset/tfgen-postgres -n tfgen
# (first start takes ~60s for the custom image to run initdb scripts)

# 5. Run DB init job (schema + seed — safe to skip if using daggu1997/tfgen_postgres image)
kubectl apply -f 05-db-init-job.yaml
kubectl wait --for=condition=complete job/tfgen-db-init -n tfgen --timeout=300s

# 6. Application layer
kubectl apply -f 06-backend-deployment.yaml
kubectl apply -f 07-frontend-deployment.yaml

# 7. Ingress + HPA
kubectl apply -f 08-ingress.yaml
kubectl apply -f 09-hpa.yaml

# 8. Verify everything is running
kubectl get all -n tfgen
kubectl get ingress -n tfgen
```

---

## Verification Commands

```bash
# Watch all pods come up
kubectl get pods -n tfgen -w

# Backend logs (look for "Server listening on port 4000")
kubectl logs -l app=tfgen-backend -n tfgen --tail=50

# Check HPA status
kubectl get hpa -n tfgen

# Port-forward backend for local testing
kubectl port-forward svc/tfgen-backend 4000:4000 -n tfgen
curl http://localhost:4000/api/health   # → {"status":"ok"}

# Port-forward frontend for local testing
kubectl port-forward svc/tfgen-frontend 8080:80 -n tfgen
# Open http://localhost:8080 in browser

# Run a DB migration (e.g. migrate_v8_more_services.sql)
kubectl run psql-tmp --rm -it --image=postgres:15 -n tfgen \
  --env="PGPASSWORD=tfgen123" \
  -- psql -h tfgen-postgres-svc -U tfgen -d terraform_generator \
     -c "\dt"   # list tables as a quick check
```

---

## Notes

- **Docker socket**: The backend mounts `/var/run/docker.sock` to run checkov
  and infracost scans via `docker run`. Pods are scheduled on whichever node
  has Docker available. In production, consider the Tecnativa socket proxy.
- **Redis URL**: BullMQ reads `REDIS_URL=redis://tfgen-redis-svc:6379` from
  the Secret. AOF persistence is enabled in the StatefulSet.
- **SKIP_STS_VERIFY=true**: Set in ConfigMap because K8s pods typically cannot
  reach `sts.amazonaws.com` without a NAT gateway. Remove if your cluster has
  outbound internet access and you want AWS credential verification.
- **Database init**: The `daggu1997/tfgen_postgres:v0.0.1` image runs
  `schema.sql` and `seed.sql` automatically on first initdb. The
  `05-db-init-job.yaml` is included for fresh vanilla postgres installs.
- **terraform-ls LSP**: Binary is baked into `daggu1997/tfgen_backend:v0.0.1`
  at `/usr/local/bin/terraform-ls`. The ConfigMap sets `TF_LSP_PATH` to that
  path. WebSocket traffic for LSP is routed via `/ws` in the Ingress.
