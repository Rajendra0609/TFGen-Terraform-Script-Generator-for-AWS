# TFGen – Kubernetes Deployment Guide

## ⚠️ Before you do anything else

The `02-secret.yaml` you had contained a real Gmail address and what is
unmistakably a real Google App Password. **Rotate that credential in your
Google Account (Security → App Passwords) now**, independently of anything
in this repo — it was exposed in a file that got zipped up and shared, so
treat it as compromised regardless of whether this manifest is ever applied.
See the big comment at the top of `02-secret.yaml` for details.

## Architecture Overview

```
Internet
   │
   ▼
┌─────────────────────────────────────────────────────────────────┐
│  Ingress (nginx) – tfgen.example.com  [ingressClassName: nginx] │
│   /ws    → tfgen-backend:4000    (WebSocket / terraform-ls LSP) │
│   /api/* → tfgen-backend:4000    (REST API)                     │
│   /*     → tfgen-frontend:80→8080 (React SPA via nginx)         │
└─────────────────────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
  ┌─────────────┐            ┌──────────────┐
  │  Backend    │            │  Frontend    │
  │  Deployment │            │  Deployment  │
  │  (2–6 pods) │            │  (2–4 pods)  │
  │  Node.js    │            │  nginx:alpine│
  │  port 4000  │            │  port 8080   │
  └──────┬──────┘            └──────────────┘
         │  (no docker.sock — see below)
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│Postgres│ │ Redis  │
│  SS    │ │  SS    │
│ (1 pod)│ │ (1 pod)│
│ 10 Gi  │ │  5 Gi  │
│        │ │ +auth  │
└────────┘ └────────┘

NetworkPolicies (11-networkpolicy.yaml) restrict all of the above to only
the traffic paths drawn here — everything else is default-denied.
```

## Files

| File | Purpose |
|------|---------|
| `00-namespace.yaml` | `tfgen` namespace |
| `01-configmap.yaml` | Non-sensitive runtime config |
| `02-secret.yaml` | DB creds, JWT secrets, ENCRYPT_KEY, SMTP, Redis password — **placeholders, see warning above and generate-secrets.sh** |
| `generate-secrets.sh` | Generates real secrets and applies them directly via `kubectl`, without writing them into a committed file |
| `03-postgres-statefulset.yaml` | PostgreSQL StatefulSet |
| `04-redis-statefulset.yaml` | Redis 7 StatefulSet — **now requires a password** |
| `05-db-init-job.yaml` | One-shot Job with schema.sql + seed.sql embedded |
| `06-backend-deployment.yaml` | Node.js/Express — **no longer mounts docker.sock** |
| `07-frontend-deployment.yaml` | nginx/React — **fixed to target the port nginx actually listens on (8080)** |
| `08-ingress.yaml` | nginx Ingress — `ingressClassName` set, TLS block ready to enable |
| `09-hpa.yaml` | HPA for backend (2–6) and frontend (2–4) — requires metrics-server |
| `10-poddisruptionbudget.yaml` | PDBs for backend/frontend so drains don't take out every replica at once |
| `11-networkpolicy.yaml` | Default-deny + explicit allows — requires a NetworkPolicy-enforcing CNI |

---

## What changed in this pass, and why

These were found by tracing each manifest against the actual application
code/Dockerfiles (not just reading the YAML in isolation) — several of
these would have caused an outage or a real security exposure, not just
style nits.

| Severity | File | Issue | Fix |
|---|---|---|---|
| 🔴 Critical | `06-backend-deployment.yaml` | Mounted the **node's** `/var/run/docker.sock` via hostPath — any pod that could reach it effectively had root on the node (and often the cluster, via kubelet creds). backend/Dockerfile's own comments say this exact pattern was already removed in favor of a socket-proxy for docker-compose. | Removed entirely. Terraform plan/validate/fmt keep working (real binaries bundled in the image); Checkov/Infracost Docker-fallback features degrade gracefully (confirmed via `isDockerAvailable()` checks in the actual code) until you add native binaries or a proper socket-proxy Deployment — see the comment left in the file. |
| 🔴 Critical | `07-frontend-deployment.yaml` | Service `targetPort`, container `containerPort`, and both probes all pointed at **80** — but nginx in this image runs as non-root and listens on **8080** (`frontend/Dockerfile`, `nginx.conf`). Nothing was listening on 80 at all: the pod would never pass its readiness/liveness probes and would crash-loop forever; traffic would never reach it either way. | All four spots corrected to 8080. |
| 🔴 Critical | `04-redis-statefulset.yaml`, `02-secret.yaml` | Redis ran with **no authentication** — `REDIS_URL` had no password, `redis-server` had no `--requirepass`. Anything in the cluster that could resolve the Service had full read/write access to session and queue data. This regressed a fix already made in `docker-compose.yml`. | Added `REDIS_PASSWORD`, wired `--requirepass $(REDIS_PASSWORD)`, rebuilt `REDIS_URL` with the password, fixed the now-authenticated liveness/readiness probes (and the backend's `wait-for-redis` init container). |
| 🔴 Critical | `02-secret.yaml` | `JWT_SECRET` and `JWT_REFRESH_SECRET` were **byte-for-byte identical** — defeats the point of separate signing keys (the project's own auth-middleware tests assert these differ). `POSTGRES_PASSWORD` was the literal string `tfgen123`. A real Gmail address + App Password were hardcoded. | Two independently-generated values for the JWT secrets; strong placeholder for the Postgres password; Gmail credential replaced with an inert placeholder (see warning at the top of this README). |
| 🟠 High | `08-ingress.yaml` | `kubernetes.io/ingress.class: nginx` annotation only — ignored by ingress-nginx v1.x, which needs `spec.ingressClassName`. No TLS at all (credentials/JWTs over plaintext HTTP). | Added `ingressClassName: nginx`; added a ready-to-uncomment `tls:` block + cert-manager notes. |
| 🟠 High | `01-configmap.yaml` | `TF_DOCKER_IMAGE` was hardcoded to a mutable tag (`hashicorp/terraform:1.15`), silently overriding the backend's own digest-pinned default that exists specifically to prevent the Terraform binary changing under you between restarts. | Removed the override so the app's verified pin applies; documented how to override safely (by digest) if you ever need to. |
| 🟡 Medium | all workloads | No `securityContext` anywhere (pods or containers) — nothing enforced non-root, dropped Linux capabilities, or blocked privilege escalation at the K8s level (even though the images themselves already run as non-root). | Added baseline `securityContext` (runAsNonRoot where compatible with each image's entrypoint, `allowPrivilegeEscalation: false`, `capabilities: drop: [ALL]`, `seccompProfile: RuntimeDefault`) plus `automountServiceAccountToken: false` — none of these pods talk to the K8s API. |
| 🟡 Medium | (new) `10-poddisruptionbudget.yaml` | No PDBs — a node drain or cluster-autoscaler scale-down could take out every backend/frontend replica at once. | Added `minAvailable: 1` PDBs for backend and frontend. |
| 🟡 Medium | (new) `11-networkpolicy.yaml` | No NetworkPolicies — `tfgen-postgres-svc`/`tfgen-redis-svc` were reachable from any pod in the cluster regardless of how strong their passwords were. | Default-deny ingress in the namespace + explicit allows (ingress-controller→frontend/backend, backend→postgres/redis). Requires a NetworkPolicy-enforcing CNI — see the comment in the file. |
| ⚪ Low | `05-db-init-job.yaml` | Job name is fixed, but Jobs are immutable — re-applying after a schema/seed change silently no-ops instead of re-running. No TTL, so completed Jobs pile up. | Documented the `kubectl delete job/tfgen-db-init` step needed before re-running; added `ttlSecondsAfterFinished: 600`. |
| ⚪ Low | `01-configmap.yaml` | Shipped `SKIP_STS_VERIFY=false`, but this project's deployment docs elsewhere say it should be `true` (no NAT gateway = pods can't reach `sts.amazonaws.com`). | Left as `false` (fails loud rather than silently skipping a real check) but flagged prominently — pick based on your actual cluster egress, don't copy either value blindly. |

---

## Pre-Deployment Checklist

### 1. Secrets

**Don't hand-edit `02-secret.yaml`'s base64 values.** Use the generator script,
which writes straight to the cluster and never touches disk with real values:

```bash
SMTP_USER='you@yourdomain.com' \
SMTP_PASS='xxxx xxxx xxxx xxxx' \
SMTP_FROM='TFGen <you@yourdomain.com>' \
FRONTEND_URL='https://tfgen.yourdomain.com' \
./generate-secrets.sh
```

This generates fresh `POSTGRES_PASSWORD` / `REDIS_PASSWORD` / `JWT_SECRET` /
`JWT_REFRESH_SECRET` / `ENCRYPT_KEY` and applies the Secret directly. If you
skip this and `kubectl apply -f 02-secret.yaml` as-is, you are deploying with
placeholder values that have appeared in this conversation — fine for a
sandbox, not for anything real.

For genuine production, consider going further: Sealed Secrets, External
Secrets Operator, or Vault, so secret material never sits in a plain
Kubernetes Secret (which is only base64, not encrypted) or in git at all.

### 2. Domain / TLS

Replace every `tfgen.example.com` in `01-configmap.yaml` and
`08-ingress.yaml` with your real domain. Then either:
- point cert-manager at it (`cert-manager.io/cluster-issuer` annotation +
  uncomment the `tls:` block in `08-ingress.yaml`), or
- provision a cert manually and `kubectl create secret tls tfgen-tls ...`
  before uncommenting the same block.

Don't skip this for a real production deployment — without it, logins and
JWTs cross the network in plaintext.

### 3. Frontend API URL

The pre-built `daggu1997/tfgen_frontend:v0.0.1` image may have
`REACT_APP_API_URL` baked in as a specific IP from an earlier build. The
current `nginx.conf` proxies `/api` same-origin, so an **empty**
`REACT_APP_API_URL` (relative calls) is the correct value going forward — if
you rebuild via the Kaniko pipeline in `jenkinsfile`, it already passes
`--build-arg REACT_APP_API_URL=` empty. Only override this if you have a
reason to call the API cross-origin.

### 4. StorageClass

Postgres/Redis PVCs have no `storageClassName` set (uses your cluster's
default). If your cluster has no default StorageClass, uncomment and set one
explicitly in `03-postgres-statefulset.yaml` / `04-redis-statefulset.yaml`
(`gp3` on EKS, `standard` on GKE/minikube/k3s).

### 5. NetworkPolicy enforcement

`11-networkpolicy.yaml` only does anything if your CNI enforces
NetworkPolicy (Calico, Cilium, most managed clusters' default CNI + add-on).
Plain flannel, for instance, does not — verify before relying on it. The
ingress-nginx pod-label selector in that file matches the common Helm chart
defaults; check yours with `kubectl get pods -n ingress-nginx --show-labels`
and adjust if different.

### 6. metrics-server (for HPA)

`09-hpa.yaml` needs the `metrics-server` add-on running in-cluster to read
CPU/memory metrics at all — most managed clusters ship it, but confirm with
`kubectl top nodes`.

---

## Deployment Steps

```bash
# 1. Namespace first
kubectl apply -f 00-namespace.yaml

# 2. Config and Secrets — see "Secrets" above; prefer generate-secrets.sh
kubectl apply -f 01-configmap.yaml
./generate-secrets.sh          # or: kubectl apply -f 02-secret.yaml

# 3. Database layer (Postgres + Redis)
kubectl apply -f 03-postgres-statefulset.yaml
kubectl apply -f 04-redis-statefulset.yaml
kubectl rollout status statefulset/tfgen-postgres -n tfgen
kubectl rollout status statefulset/tfgen-redis    -n tfgen

# 4. DB init job (safe to skip if using daggu1997/tfgen_postgres, which
#    already runs schema/seed via initdb on first boot — see its Dockerfile)
kubectl apply -f 05-db-init-job.yaml
kubectl wait --for=condition=complete job/tfgen-db-init -n tfgen --timeout=300s

# 5. Application layer
kubectl apply -f 06-backend-deployment.yaml
kubectl apply -f 07-frontend-deployment.yaml

# 6. Ingress, HPA, PDBs, NetworkPolicies
kubectl apply -f 08-ingress.yaml
kubectl apply -f 09-hpa.yaml
kubectl apply -f 10-poddisruptionbudget.yaml
kubectl apply -f 11-networkpolicy.yaml

# 7. Verify
kubectl get all -n tfgen
kubectl get ingress -n tfgen
kubectl get networkpolicy -n tfgen
```

---

## Verification Commands

```bash
# Watch all pods come up
kubectl get pods -n tfgen -w

# Backend logs (look for "Server listening on port 4000")
kubectl logs -l app=tfgen-backend -n tfgen --tail=50

# Frontend pod should now actually pass readiness (was crash-looping on the
# port-80/8080 mismatch before this pass)
kubectl get pods -l app=tfgen-frontend -n tfgen

# Check HPA status
kubectl get hpa -n tfgen

# Port-forward backend for local testing
kubectl port-forward svc/tfgen-backend 4000:4000 -n tfgen
curl http://localhost:4000/api/health   # → {"status":"ok"}

# Port-forward frontend for local testing
kubectl port-forward svc/tfgen-frontend 8080:80 -n tfgen
# Open http://localhost:8080 in browser

# Confirm Redis actually requires auth now
kubectl run redis-cli-tmp --rm -it --image=redis:7 -n tfgen -- \
  redis-cli -h tfgen-redis-svc ping
# → should return "NOAUTH Authentication required." (proves it's no longer open)
```

---

## Notes

- **Docker socket removed**: Checkov/Infracost's Docker-fallback path is
  unavailable in this cluster until you either install native `checkov`/
  `infracost` binaries in `backend/Dockerfile` (recommended — removes the
  Docker dependency for good) or stand up a locked-down docker-socket-proxy
  Deployment. See the comment in `06-backend-deployment.yaml`.
- **Redis**: now requires `REDIS_PASSWORD` (see `02-secret.yaml`). AOF
  persistence remains enabled in the StatefulSet.
- **SKIP_STS_VERIFY**: shipped as `false` — decide based on whether your
  pods have outbound internet access to `sts.amazonaws.com` (see the
  comment in `01-configmap.yaml`).
- **Database init**: `daggu1997/tfgen_postgres:v0.0.1` runs `schema.sql`/
  `seed.sql` automatically on first initdb; `05-db-init-job.yaml` exists for
  fresh vanilla-postgres installs, and is safe to re-run after a
  `kubectl delete job` (the SQL itself is idempotent).
- **terraform-ls LSP**: binary is baked into
  `daggu1997/tfgen_backend:v0.0.1` at `/usr/local/bin/terraform-ls`.
  WebSocket traffic for it is routed via `/ws` in the Ingress.
