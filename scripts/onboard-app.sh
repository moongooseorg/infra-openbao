#!/usr/bin/env bash
set -euo pipefail

APP="${1:?usage: onboard-app.sh <app-name> <owner/repo>}"
REPO="${2:?usage: onboard-app.sh <app-name> <owner/repo>}"
: "${BAO_ADDR:?BAO_ADDR must be set}"
: "${BAO_TOKEN:?BAO_TOKEN must be set}"
: "${BAO_CACERT:?BAO_CACERT must be set}"
KV_MOUNT="${KV_MOUNT:-kv}"
: "${GH_TOKEN:?GH_TOKEN must be set}"

[[ "$APP" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "invalid app name: $APP" >&2; exit 1; }

bao() {
  curl -sS --fail-with-body --cacert "$BAO_CACERT" -H "X-Vault-Token: $BAO_TOKEN" "$@"
}

status=$(curl -sS -o /dev/null -w '%{http_code}' --cacert "$BAO_CACERT" -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/$KV_MOUNT/metadata/$APP")
if [[ "$status" == "404" ]]; then
  echo "Creating $KV_MOUNT/$APP"
  bao -X POST "$BAO_ADDR/v1/$KV_MOUNT/data/$APP" \
    -d '{"options":{"cas":0},"data":{"placeholder":"replace-me"}}' >/dev/null
elif [[ "$status" == "200" ]]; then
  echo "$KV_MOUNT/$APP already exists"
else
  echo "unexpected status $status checking $KV_MOUNT/$APP" >&2
  exit 1
fi

echo "Writing policy $APP"
policy=$(printf 'path "%s/data/%s" {\n    capabilities = ["read"]\n}\n' "$KV_MOUNT" "$APP")
jq -n --arg p "$policy" '{policy: $p}' | bao -X PUT "$BAO_ADDR/v1/sys/policies/acl/$APP" -d @- >/dev/null

echo "Writing approle $APP"
jq -n --arg p "$APP" '{token_policies: $p, token_ttl: "20m", token_max_ttl: "1h", secret_id_ttl: 0, secret_id_num_uses: 0}' \
  | bao -X POST "$BAO_ADDR/v1/auth/approle/role/$APP" -d @- >/dev/null

role_id=$(bao "$BAO_ADDR/v1/auth/approle/role/$APP/role-id" | jq -er .data.role_id)
secret_id=$(bao -X POST "$BAO_ADDR/v1/auth/approle/role/$APP/secret-id" | jq -er .data.secret_id)
[[ -n "${GITHUB_ACTIONS:-}" ]] && echo "::add-mask::$secret_id"

echo "Setting GitHub secrets on $REPO"
printf '%s' "$role_id" | gh secret set BAO_ROLE_ID --repo "$REPO"
printf '%s' "$secret_id" | gh secret set BAO_SECRET_ID --repo "$REPO"

echo "Onboarded $APP"
