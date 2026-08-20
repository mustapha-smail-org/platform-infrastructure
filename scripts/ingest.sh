#!/usr/bin/env bash
# Run the data-ingestion batch once, then let it exit. Invoked by host cron
# (see host/data-ingestion.cron.example). `run --rm` starts a fresh one-shot
# container from the pinned digest and removes it on exit, so it holds memory
# only while actually ingesting.
#
#   scripts/ingest.sh <prod|staging>
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

ENV="${1:?usage: ingest.sh <prod|staging>}"
require_env "$ENV"

echo ">> $(date -Is) starting data-ingestion batch for ${ENV}"
compose "$ENV" --profile batch run --rm data-ingestion
echo ">> $(date -Is) data-ingestion batch finished for ${ENV}"
