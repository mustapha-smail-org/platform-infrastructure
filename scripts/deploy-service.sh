#!/usr/bin/env bash
# Surgical single-service rollout. Runs ON the VPS; CI invokes it over SSH after
# it has already dropped the resolved config into environments/<env>/secrets/.
#
#   scripts/deploy-service.sh <prod|staging> <service> <sha256:digest>
#
# Steps: re-pin the ONE digest line (under flock so concurrent deploys can't
# clobber each other), pull, recreate only that container (--no-deps leaves
# siblings running), wait for health, and roll the pin back if it never goes
# healthy. Nothing else in the stack restarts.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

ENV="${1:?usage: deploy-service.sh <prod|staging> <service> <sha256:digest>}"
SERVICE="${2:?missing service name}"
DIGEST="${3:?missing image digest}"

require_env "$ENV"
[[ -n "${DIGEST_VAR[$SERVICE]:-}" ]] || die "unknown service '$SERVICE'"
[[ "$DIGEST" =~ ^sha256:[a-f0-9]{64}$ ]] || die "digest must be sha256:<64 hex>, got: $DIGEST"

VAR="${DIGEST_VAR[$SERVICE]}"
EF="$(env_file "$ENV")"

# --- re-pin the digest line atomically, remembering the old value -----------
exec 9>"${EF}.lock"; flock 9
OLD_DIGEST="$(grep -E "^${VAR}=" "$EF" | head -1 | cut -d= -f2-)"
sed -i.bak -E "s|^(${VAR}=).*|\1${DIGEST}|" "$EF" && rm -f "${EF}.bak"
echo ">> ${ENV}/${SERVICE}: ${OLD_DIGEST}  ->  ${DIGEST}"

rollback() {
  echo "!! rolling ${SERVICE} back to ${OLD_DIGEST}" >&2
  sed -i.bak -E "s|^(${VAR}=).*|\1${OLD_DIGEST}|" "$EF" && rm -f "${EF}.bak"
  compose "$ENV" up -d --no-deps "$SERVICE" || true
  exit 1
}

# --- recreate just this service --------------------------------------------
compose "$ENV" pull "$SERVICE"
compose "$ENV" up -d --no-deps "$SERVICE"

# data-ingestion is a run-once batch (profile-gated); it has no long-running
# container to health-check, so pinning the digest is the whole "deploy".
if [[ "$SERVICE" == "data-ingestion" ]]; then
  echo ">> data-ingestion digest pinned; it runs on its schedule (see ingest.sh)."
  exit 0
fi

# --- wait for the container's healthcheck to pass ---------------------------
CID="$(compose "$ENV" ps -q "$SERVICE")"
[[ -n "$CID" ]] || rollback
echo ">> waiting for ${SERVICE} to become healthy..."
for _ in $(seq 1 40); do   # ~40 * 5s = 200s, covers JVM start_period
  status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$CID" 2>/dev/null || echo gone)"
  case "$status" in
    healthy) echo ">> ${SERVICE} healthy."; break;;
    unhealthy|gone) rollback;;
  esac
  sleep 5
done
[[ "${status:-}" == "healthy" ]] || rollback

# No frontend reload needed after a gateway rollout: the frontend nginx uses a
# Docker resolver and re-resolves the gateway's IP per request.

echo ">> done."
