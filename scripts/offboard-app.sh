#!/usr/bin/env bash
set -euo pipefail

APP="${1:?usage: offboard-app.sh <app-name> <owner/repo>}"
REPO="${2:?usage: offboard-app.sh <app-name> <owner/repo>}"
: "${BAO_ADDR:?BAO_ADDR must be set}"
: "${BAO_TOKEN:?BAO_TOKEN must be set}"
: "${BAO_CACERT:?BAO_CACERT must be set}"
KV_MOUNT="${KV_MOUNT:-kv}"
: "${GH_TOKEN:?GH_TOKEN must be set}"

[[ "$APP" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "invalid app name: $APP" >&2; exit 1; }

bao() {
  curl -sS --fail-with-body --cacert "$BAO_CACERT" -H "X-Vault-Token: $BAO_TOKEN" "$@"
}

echo "Deleting approle $APP"
bao -X DELETE "$BAO_ADDR/v1/auth/approle/role/$APP" >/dev/null

echo "Deleting policy $APP"
bao -X DELETE "$BAO_ADDR/v1/sys/policies/acl/$APP" >/dev/null

echo "Deleting $KV_MOUNT/$APP and all versions"
bao -X DELETE "$BAO_ADDR/v1/$KV_MOUNT/metadata/$APP" >/dev/null

echo "Removing GitHub secrets from $REPO"
gh secret delete BAO_ROLE_ID --repo "$REPO" || echo "BAO_ROLE_ID not removed"
gh secret delete BAO_SECRET_ID --repo "$REPO" || echo "BAO_SECRET_ID not removed"

echo "Offboarded $APP"
