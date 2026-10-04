#!/usr/bin/env bash
set -euo pipefail

ORG="${1:?usage: bootstrap.sh <github-org>}"
REPO="${2:?usage: bootstrap.sh <github-org> <secret-repo>}"
: "${BAO_ADDR:?BAO_ADDR must be set}"
: "${BAO_CACERT:?BAO_CACERT must be set}"
: "${GH_TOKEN:?GH_TOKEN must be set}"
: "${BAO_ADMIN_PASSWORD:?BAO_ADMIN_PASSWORD must be set}"
KV_MOUNT="${KV_MOUNT:-kv}"
ADMIN_POLICY_FILE="$(dirname "$0")/../policies/admin.hcl"
[[ -f "$ADMIN_POLICY_FILE" ]] || { echo "missing $ADMIN_POLICY_FILE" >&2; exit 1; }

api() {
  curl -sS --fail-with-body --cacert "$BAO_CACERT" "$@"
}

for _ in $(seq 1 30); do
  init_status=$(api "$BAO_ADDR/v1/sys/init" 2>/dev/null) && break
  sleep 2
done
[[ -n "${init_status:-}" ]] || { echo "OpenBao not reachable at $BAO_ADDR" >&2; exit 1; }

initialized=$(jq -er '.initialized | tostring' <<<"$init_status")
if [[ "$initialized" == "false" ]]; then
  echo "Checking access to $ORG organisation secrets"
  gh secret list --org "$ORG" >/dev/null

  echo "Initialising OpenBao"
  init=$(api -X PUT "$BAO_ADDR/v1/sys/init" -d '{"recovery_shares":1,"recovery_threshold":1}')
  BAO_TOKEN=$(jq -er .root_token <<<"$init")
  recovery_key=$(jq -er '.recovery_keys_b64[0]' <<<"$init")
  [[ -n "${GITHUB_ACTIONS:-}" ]] && echo "::add-mask::$BAO_TOKEN" && echo "::add-mask::$recovery_key"

  echo "Storing BAO_TOKEN and BAO_RECOVERY_KEY as $ORG secrets"
  printf '%s' "$BAO_TOKEN" | gh secret set BAO_TOKEN --org "$ORG" --repos "$REPO"
  printf '%s' "$recovery_key" | gh secret set BAO_RECOVERY_KEY --org "$ORG" --repos "$REPO"
elif [[ "$initialized" == "true" ]]; then
  echo "OpenBao already initialised"
  : "${BAO_TOKEN:?BAO_TOKEN must be set when OpenBao is already initialised}"
else
  echo "unexpected init status: $init_status" >&2
  exit 1
fi

for _ in $(seq 1 30); do
  [[ "$(api "$BAO_ADDR/v1/sys/seal-status" | jq -r .sealed)" == "false" ]] && break
  sleep 2
done

bao() {
  api -H "X-Vault-Token: $BAO_TOKEN" "$@"
}

if bao "$BAO_ADDR/v1/sys/mounts" | jq -e --arg m "$KV_MOUNT/" 'has($m)' >/dev/null; then
  echo "Secrets engine $KV_MOUNT already enabled"
else
  echo "Enabling kv v2 secrets engine at $KV_MOUNT"
  bao -X POST "$BAO_ADDR/v1/sys/mounts/$KV_MOUNT" -d '{"type":"kv","options":{"version":"2"}}' >/dev/null
fi

if bao "$BAO_ADDR/v1/sys/auth" | jq -e 'has("approle/")' >/dev/null; then
  echo "AppRole auth already enabled"
else
  echo "Enabling AppRole auth"
  bao -X POST "$BAO_ADDR/v1/sys/auth/approle" -d '{"type":"approle"}' >/dev/null
fi

if bao "$BAO_ADDR/v1/sys/auth" | jq -e 'has("userpass/")' >/dev/null; then
  echo "Userpass auth already enabled"
else
  echo "Enabling Userpass auth"
  bao -X POST "$BAO_ADDR/v1/sys/auth/userpass" -d '{"type":"userpass"}' >/dev/null
fi

echo "Writing admin policy"
jq -n --rawfile p "$ADMIN_POLICY_FILE" '{policy: $p}' | bao -X PUT "$BAO_ADDR/v1/sys/policies/acl/admin" -d @- >/dev/null

echo "Writing admin user"
jq -n --arg pw "$BAO_ADMIN_PASSWORD" '{password: $pw, token_policies: "admin"}' \
  | bao -X POST "$BAO_ADDR/v1/auth/userpass/users/admin" -d @- >/dev/null

echo "Bootstrap complete"
