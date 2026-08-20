#!/usr/bin/env bash
# Shared helpers for the CityPulse deploy scripts. Sourced, not run directly.
set -euo pipefail

# Repo root = parent of this scripts/ dir, regardless of caller's cwd.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Every service<->env-var mapping in one place.
#   service name (compose)      -> env-file variable holding its digest
declare -A DIGEST_VAR=(
  [api-gateway]=API_GATEWAY_DIGEST
  [catalog-service]=CATALOG_SERVICE_DIGEST
  [data-ingestion]=DATA_INGESTION_DIGEST
  [frontend]=FRONTEND_DIGEST
)

env_file() { echo "${REPO_ROOT}/environments/$1/.env"; }

# Thin wrapper: always pin the env file + project name for the given environment.
compose() {
  local env="$1"; shift
  docker compose --env-file "$(env_file "$env")" -p "citypulse-${env}" \
    -f "${REPO_ROOT}/docker-compose.yml" "$@"
}

die() { echo "ERROR: $*" >&2; exit 1; }

require_env() {
  case "$1" in
    prod|staging) : ;;
    *) die "unknown environment '$1' (expected: prod | staging)";;
  esac
  [[ -f "$(env_file "$1")" ]] || die "missing env file: $(env_file "$1") (copy from .env.example)"
}
