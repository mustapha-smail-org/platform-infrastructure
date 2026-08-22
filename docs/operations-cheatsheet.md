# Operations cheat sheet

Day-to-day and debugging commands. Run from `/opt/citypulse/platform-infrastructure`
as `deployer`.

## The compose invocation (memorize this)

Every command is `docker compose` + which env file + which project. The **app**
stacks use the default root `docker-compose.yml`; **edge** and **observability**
need an explicit `-f`:

```bash
# app envs (prod / staging)
docker compose --env-file environments/<env>/.env -p citypulse-<env> <cmd>

# edge (Caddy)
docker compose --env-file edge/.env -f edge/docker-compose.yml -p citypulse-edge <cmd>

# observability (Alloy)
docker compose --env-file observability/.env -f observability/docker-compose.yml -p citypulse-observability <cmd>
```

Services: `api-gateway`, `catalog-service`, `data-ingestion` (batch), `frontend`.

## Status & health

```bash
# what's running + healthy in an env
docker compose --env-file environments/prod/.env -p citypulse-prod ps

# a container's healthcheck history (why is it unhealthy?)
docker inspect --format '{{range .State.Health.Log}}exit={{.ExitCode}} {{.Output}}{{end}}' citypulse-prod-catalog-service-1
```

## Logs

```bash
# live tail one service
docker compose --env-file environments/prod/.env -p citypulse-prod logs -f api-gateway

# last N lines / since a time
docker compose --env-file environments/prod/.env -p citypulse-prod logs --tail=200 catalog-service
docker compose --env-file environments/prod/.env -p citypulse-prod logs --since 15m frontend

# ingestion batch (host cron writes here)
tail -n 100 /var/log/citypulse/ingest-prod.log
```

For anything historical, use **Grafana Cloud** (Loki) — filter `{env="citypulse-prod", service="catalog-service"}`.

## Restart / recreate a service

```bash
# restart (keeps config) — does NOT pick up .env or compose changes
docker compose --env-file environments/prod/.env -p citypulse-prod restart catalog-service

# recreate (picks up compose/.env/healthcheck changes; needed after editing those)
docker compose --env-file environments/prod/.env -p citypulse-prod up -d --no-deps --force-recreate catalog-service
```

Rule of thumb: **changed a file/env → `up -d` (recreate)**, not `restart`.

## Deploy / roll back one service (manual)

Normally CI does this; by hand:

```bash
# pin a new digest, pull, recreate, health-gate, auto-rollback on failure
scripts/deploy-service.sh prod catalog-service sha256:<digest>
```

## Run the ingestion batch on demand

```bash
scripts/ingest.sh prod        # runs once, exits
```

## Staging on / off

```bash
scripts/staging.sh up         # bring staging up for a test
scripts/staging.sh status
scripts/staging.sh down       # stop it; hands all RAM back to prod
```

## Get inside a container

```bash
docker compose --env-file environments/prod/.env -p citypulse-prod exec catalog-service sh
# one-off command:
docker compose --env-file environments/prod/.env -p citypulse-prod exec -T frontend cat /etc/secrets/app-config.json
```

## Test the request chain (bypass layers to isolate a fault)

```bash
# catalog readiness, straight (internal network)
docker run --rm --network citypulse-prod_internal curlimages/curl -fsS http://catalog-service:8080/actuator/health/readiness

# does the gateway serve the API? (gateway -> catalog)
docker run --rm --network citypulse-prod_internal curlimages/curl -s -o /dev/null -w "%{http_code}\n" http://api-gateway:8080/api/v1/categories

# full chain via the frontend (frontend -> gateway -> catalog)
docker run --rm --network citypulse-edge curlimages/curl -s -o /dev/null -w "%{http_code}\n" http://frontend-prod:8080/api/v1/categories

# public, through Caddy
curl https://<prod-host>/api/v1/categories
```

## Resources (the 4 GB box)

```bash
free -m                        # host memory / swap
docker stats --no-stream       # per-container CPU/mem
df -h /                        # disk
```
If tight: `scripts/staging.sh down`.

## After a reboot (bring everything back)

```bash
cd /opt/citypulse/platform-infrastructure
docker compose --env-file edge/.env -f edge/docker-compose.yml -p citypulse-edge up -d
docker compose --env-file environments/prod/.env -p citypulse-prod up -d
docker compose --env-file observability/.env -f observability/docker-compose.yml -p citypulse-observability up -d
# staging only if you need it: scripts/staging.sh up
```
(`restart: unless-stopped` brings containers back on Docker start, but running
`up -d` guarantees the intended state.)

## Cleanup (reclaim disk)

```bash
docker image prune -f                 # dangling images
docker system prune -f                # unused images/networks (careful; not volumes)
```
Avoid `--volumes` — it would wipe Caddy's cert store (`caddy_data`).

## Gotchas to keep in mind

- **Place secret files before the first `up`** for an env. Docker creates
  root-owned *directories* at missing bind-mount paths → later scp/deploys fail.
- **Inside a container, use `127.0.0.1`, not `localhost`** for health/self checks
  — `localhost` may resolve to IPv6 `::1` where the server isn't listening.
- **`.env` / compose changes need `up -d`**, not `restart`.
- **edge & observability always need `-f`**; forgetting it makes compose use the
  app topology by mistake.
- **Secrets/`.env` live only on the box** (git-ignored). The repo has `.example`
  templates.
