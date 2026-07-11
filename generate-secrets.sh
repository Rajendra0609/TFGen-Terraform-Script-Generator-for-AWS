#!/usr/bin/env bash
# generate-secrets.sh
#
# Generates strong, unique production secrets and applies them straight to
# the cluster with `kubectl create secret ... --from-literal`, WITHOUT ever
# writing real values into 02-secret.yaml (or anywhere else on disk that
# might get committed to git).
#
# Usage:
#   ./generate-secrets.sh                     # generate everything fresh
#   SMTP_USER=you@yourdomain.com \
#   SMTP_PASS='xxxx xxxx xxxx xxxx' \
#   SMTP_FROM='TFGen <you@yourdomain.com>' \
#   FRONTEND_URL=https://tfgen.yourdomain.com \
#   ./generate-secrets.sh                     # override the values that
#                                              # can't be auto-generated
#
# Re-running this rotates POSTGRES_PASSWORD/REDIS_PASSWORD/JWT_*/ENCRYPT_KEY
# every time — don't run it casually against a live production namespace
# without planning for the restart it'll trigger (kubectl apply/replace on
# the Secret doesn't itself restart pods; you still need a rollout restart
# for the new values to take effect — see the end of this script).

set -euo pipefail

NAMESPACE="${NAMESPACE:-tfgen}"

POSTGRES_USER="${POSTGRES_USER:-tfgen}"
POSTGRES_DB="${POSTGRES_DB:-terraform_generator}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/')}"
REDIS_PASSWORD="${REDIS_PASSWORD:-$(openssl rand -base64 24 | tr -d '=+/')}"
JWT_SECRET="${JWT_SECRET:-$(openssl rand -hex 32)}"
JWT_REFRESH_SECRET="${JWT_REFRESH_SECRET:-$(openssl rand -hex 32)}"
ENCRYPT_KEY="${ENCRYPT_KEY:-$(openssl rand -hex 32)}"

# These can't be auto-generated — you must supply real values (env vars, see
# Usage above) or accept the placeholders and edit the Secret afterwards.
SMTP_USER="${SMTP_USER:-CHANGE_ME@example.com}"
SMTP_PASS="${SMTP_PASS:-CHANGE_ME_16_char_app_password}"
SMTP_FROM="${SMTP_FROM:-TFGen <CHANGE_ME@example.com>}"
FRONTEND_URL="${FRONTEND_URL:-https://tfgen.example.com}"

if [[ "$JWT_SECRET" == "$JWT_REFRESH_SECRET" ]]; then
  echo "ERROR: JWT_SECRET and JWT_REFRESH_SECRET ended up identical — refusing to proceed." >&2
  exit 1
fi

DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@tfgen-postgres-svc:5432/${POSTGRES_DB}"
REDIS_URL="redis://:${REDIS_PASSWORD}@tfgen-redis-svc:6379"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic tfgen-secret \
  --namespace "$NAMESPACE" \
  --from-literal=POSTGRES_USER="$POSTGRES_USER" \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  --from-literal=POSTGRES_DB="$POSTGRES_DB" \
  --from-literal=DATABASE_URL="$DATABASE_URL" \
  --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD" \
  --from-literal=REDIS_URL="$REDIS_URL" \
  --from-literal=JWT_SECRET="$JWT_SECRET" \
  --from-literal=JWT_REFRESH_SECRET="$JWT_REFRESH_SECRET" \
  --from-literal=ENCRYPT_KEY="$ENCRYPT_KEY" \
  --from-literal=SMTP_USER="$SMTP_USER" \
  --from-literal=SMTP_PASS="$SMTP_PASS" \
  --from-literal=SMTP_FROM="$SMTP_FROM" \
  --from-literal=FRONTEND_URL="$FRONTEND_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✅ tfgen-secret applied to namespace '$NAMESPACE'."
if [[ "$SMTP_USER" == "CHANGE_ME@example.com" ]]; then
  echo "⚠️  SMTP_USER/SMTP_PASS/SMTP_FROM are still placeholders — password-reset"
  echo "    and notification emails will fail to send until you re-run this with"
  echo "    real values (see Usage at the top of this script)."
fi
echo ""
echo "Existing backend/postgres/redis pods do NOT pick up the new values until"
echo "restarted. Roll them now:"
echo "  kubectl rollout restart statefulset/tfgen-postgres -n $NAMESPACE"
echo "  kubectl rollout restart statefulset/tfgen-redis    -n $NAMESPACE"
echo "  kubectl rollout restart deployment/tfgen-backend   -n $NAMESPACE"
