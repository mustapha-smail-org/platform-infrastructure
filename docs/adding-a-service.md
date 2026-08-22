# Adding a new service — infrastructure steps

This covers only the **infrastructure** side (this repo). It assumes the service
itself and its `<service>-cd` repo already exist (built + pushed to GHCR, with a
`deploy.yml` mirroring the others).

Example: adding a service called `notification-service`, internal-only, that
needs a resolved config file.

## 1. Add it to the topology — `docker-compose.yml`

Add a service block (copy `catalog-service` and adapt):

```yaml
  notification-service:
    image: "${NOTIFICATION_SERVICE_IMAGE}@${NOTIFICATION_SERVICE_DIGEST}"
    restart: unless-stopped
    stop_grace_period: 30s
    environment:
      SPRING_PROFILES_ACTIVE: "${SPRING_PROFILES_ACTIVE}"
      JAVA_TOOL_OPTIONS: "${NOTIFICATION_JAVA_OPTS}"
    mem_limit: "${NOTIFICATION_MEM_LIMIT}"
    cpus: ${NOTIFICATION_CPUS}
    volumes:   # only if it needs a resolved config / CA
      - "${SECRETS_DIR}/application-notification-service.yaml:/etc/secrets/application.yaml:ro"
    networks:
      internal: {}
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8080/actuator/health/readiness >/dev/null 2>&1 || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 10
      start_period: 70s
```

Decisions:
- **Internal vs public** — internal-only services join just `internal`. Only add
  the `edge` network + an alias if it must be reachable from the internet
  (see step 5). Most services stay internal, reached via the gateway.
- **Batch** — if it runs and exits, add `profiles: ["batch"]`, `restart: "no"`,
  and skip the healthcheck (see `data-ingestion`), then wire a host cron.

## 2. Add its knobs to each env file — `environments/<env>/.env(.example)`

```
NOTIFICATION_SERVICE_IMAGE=ghcr.io/mustapha-smail-org/notification-service
NOTIFICATION_SERVICE_DIGEST=sha256:0000...0000
NOTIFICATION_MEM_LIMIT=384m
NOTIFICATION_JAVA_OPTS=-XX:MaxRAMPercentage=60.0 -XX:+ExitOnOutOfMemoryError
NOTIFICATION_CPUS=1.0
```
Do this in **both** `prod/.env` and `staging/.env` (and the `.example`s). Mind
the 4 GB budget — check `free -m` headroom before adding a resident JVM.

## 3. Register it for deploys — `scripts/lib.sh`

Add to the `DIGEST_VAR` map so `deploy-service.sh` knows its digest variable:

```bash
declare -A DIGEST_VAR=(
  [api-gateway]=API_GATEWAY_DIGEST
  [catalog-service]=CATALOG_SERVICE_DIGEST
  [data-ingestion]=DATA_INGESTION_DIGEST
  [frontend]=FRONTEND_DIGEST
  [notification-service]=NOTIFICATION_SERVICE_DIGEST   # <-- add
)
```

## 4. Secrets (if it needs config)

Document the expected file in `environments/<env>/secrets/README.md`. The
service's `-cd` `push-config` job (using the shared `resolve-config` action)
resolves and delivers `application-notification-service.yaml` to
`environments/<env>/secrets/`. No infra change beyond the volume mount in step 1.

## 5. Only if it must be public — edge

- Give it an `edge` alias in `docker-compose.yml`:
  ```yaml
    networks:
      internal: {}
      edge:
        aliases: ["${NOTIFICATION_EDGE_ALIAS}"]
  ```
- Add `NOTIFICATION_EDGE_ALIAS=notification-<env>` to each `.env`.
- Add a route + hostname in `edge/Caddyfile` and a host var in `edge/.env`.

Usually you **don't** need this — internal services are reached through the
gateway. If it's a gateway-routed API, instead add the gateway route/env in the
api-gateway config, not here.

## 6. Apply on the box

New services are a **topology change**, so do a full reconcile (not a
single-service deploy):

```bash
# sync this repo to the box, then:
docker compose --env-file environments/prod/.env -p citypulse-prod up -d
```
This creates the new container. From then on its `-cd` deploy pins the digest
via `scripts/deploy-service.sh`.

## 7. Observability — nothing to do

Alloy discovers all Docker containers automatically, so logs + metrics for the
new service appear in Grafana Cloud with no config change.

## Checklist

- [ ] service block in `docker-compose.yml` (internal/public/batch decided)
- [ ] `<SVC>_IMAGE/DIGEST/MEM_LIMIT/JAVA_OPTS/CPUS` in both env files (+ examples)
- [ ] entry in `scripts/lib.sh` `DIGEST_VAR`
- [ ] secret file documented (if any) + volume mount
- [ ] edge alias/route (only if public)
- [ ] full `up -d` on the box to create it
