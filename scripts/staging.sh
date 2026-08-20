#!/usr/bin/env bash
# Turn the staging environment on or off. `down` returns all of staging's RAM
# to production; `up` brings it back for a test run. Prod is never touched.
#
#   scripts/staging.sh up | down | status
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_env staging

case "${1:-}" in
  up)     compose staging up -d && echo ">> staging up.";;
  down)   compose staging down  && echo ">> staging down — prod now owns the box.";;
  status) compose staging ps;;
  *) die "usage: staging.sh up | down | status";;
esac
