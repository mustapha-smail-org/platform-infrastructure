# 9 · Reference

## Compose invocation

Always pin the env file and project name:

```bash
docker compose --env-file environments/<env>/.env -p citypulse-<env> <cmd>
docker compose --env-file edge/.env               -p citypulse-edge  <cmd>
```

`scripts/*.sh` wrap this for you.

## Projects, networks, exposure

| Env | Compose project | Internal network | Public? |
|-----|-----------------|------------------|---------|
| prod | `citypulse-prod` | `citypulse-prod_internal` | frontend only, via Caddy |
| staging | `citypulse-staging` | `citypulse-staging_internal` | frontend only, via Caddy |
| edge | `citypulse-edge` | `citypulse-edge` (external) | binds host **80/443** |

Only Caddy binds host ports. Every app container listens on **8080** inside its
own network; nothing else is published to the host.

## `.env` variable contract

| Variable | Meaning |
|----------|---------|
| `COMPOSE_PROJECT_NAME` | `citypulse-<env>` |
| `SECRETS_DIR` | path to this env's `secrets/` |
| `FRONTEND_EDGE_ALIAS` | `frontend-<env>` (Caddy target) |
| `SPRING_PROFILES_ACTIVE` | `production` / `staging` |
| `ALLOWED_ORIGINS` | public app origin (gateway CORS) |
| `<SVC>_IMAGE` | GHCR repo (stable) |
| `<SVC>_DIGEST` | pinned `sha256:...` (the version ledger) |
| `<SVC>_MEM_LIMIT` | container memory cap |
| `<SVC>_JAVA_OPTS` | `JAVA_TOOL_OPTIONS` (heap `MaxRAMPercentage`) |
| `<SVC>_CPUS` | CPU cap |

`<SVC>` ∈ `API_GATEWAY`, `CATALOG_SERVICE`, `DATA_INGESTION`, `FRONTEND`
(GATEWAY/CATALOG/INGESTION/FRONTEND for the cap prefixes).

## Secret files (`environments/<env>/secrets/`, `600`)

| File | Mounted at | Used by |
|------|------------|---------|
| `application-catalog-service.yaml` | `/etc/secrets/application.yaml` | catalog-service |
| `application-data-ingestion.yaml` | `/etc/secrets/application.yaml` | data-ingestion |
| `app-config.json` | `/etc/secrets/app-config.json` | frontend |
| `kafka-ca.pem` | `/etc/secrets/ca.pem` | catalog, ingestion |

api-gateway: no file — env-driven from `.env`.

## Scripts

| Script | Purpose |
|--------|---------|
| `host/bootstrap.sh <pubkey>` | one-time host hardening + Docker + edge network (run as root) |
| `scripts/deploy-service.sh <env> <service> <digest>` | surgical single-service rollout, health-gated + rollback |
| `scripts/staging.sh up\|down\|status` | staging on/off switch |
| `scripts/ingest.sh <env>` | run the ingestion batch once |
| `host/data-ingestion.cron.example` | host cron entry for scheduled ingestion |

## Manual (human-only) steps — consolidated checklist

Everything the repo can't do for you, in setup order:

- [ ] 🔧 Order the OVH VPS (Ubuntu 26.04); note the public IP.
- [ ] 🔧 Generate your admin SSH keypair.
- [ ] 🔧 Create a GHCR **read** PAT.
- [ ] 🔧 Run `bootstrap.sh <pubkey>` as root; reconnect as `deployer`.
- [ ] 🔧 `docker login ghcr.io` with the PAT.
- [ ] 🔧 Create the staging Postgres DB and Kafka topics + **distinct consumer group**.
- [ ] 🔧 Resolve `%%SECRET%%` config into `secrets/` (PRD for prod, HPR for staging); `chmod 600`.
- [ ] 🔧 Fill `environments/<env>/.env` digests and `ALLOWED_ORIGINS`.
- [ ] 🔧 Set `edge/.env` hostnames (temporary `nip.io` until the domain exists).
- [ ] 🔧 Install the ingestion cron; run `scripts/ingest.sh` once to verify.
- [ ] 🔧 (Later) Buy the domain; add A records; update hostnames + origins.

## See also

- [`docs/VPS/vps-deployment-design.md`](../../docs/VPS/vps-deployment-design.md) — design rationale.
- [`README.md`](../README.md) — condensed repo overview.
