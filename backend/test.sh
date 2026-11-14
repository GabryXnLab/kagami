#!/usr/bin/env bash
# Prova schema e regole su un Postgres usa e getta in Docker, mai su un backend vero.
#   backend/test.sh        (POSTGRES_IMAGE per un'altra versione)
set -euo pipefail
cd "$(dirname "$0")"
docker run --rm -v "$PWD":/backend:ro "${POSTGRES_IMAGE:-postgres:17-alpine}" su postgres -c '
  initdb -A trust -D /tmp/pg >/dev/null 2>&1 && pg_ctl -D /tmp/pg -w -o "-c listen_addresses=" start >/dev/null &&
  psql -q -o /dev/null -v ON_ERROR_STOP=1 -f /backend/local-shim.sql -f /backend/schema.sql -f /backend/rls-test.sql'
