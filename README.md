# platform-infrastructure

Single-host deployment for CityPulse on one OVH VPS (2 vCPU / 4 GB). Runs **staging + production side by side** on one
box, each fully isolated, with staging switchable off so production can own all
4 GB.

> `dev` is not deployed here — it's local `docker compose` on your laptop.

## Topology

```
                 Internet · 443
                      │
                   ┌──▼── Caddy ──┐         edge/  (always on, auto-TLS)
        app host →  │              │ ← staging app host
              ┌─────▼─────┐  ┌─────▼──────┐
              │ prod      │  │ staging    │   separate compose projects
              │ frontend  │  │ frontend   │   = separate Docker networks
              │   ↓ /api  │  │   ↓ /api   │
              │ api-gateway│ │ api-gateway│   internal only
              │   ↓        │  │   ↓        │
              │ catalog    │  │ catalog    │
              │ (ingestion │  │ (ingestion │   batch: cron → run → exit
              │  batch)    │  │  batch)    │
              └─────┬──────┘  └─────┬──────┘
                    ▼                ▼
        Aiven Postgres · Confluent Kafka   (managed, off-box; per-env DB/topics/group)
```

Only `frontend` is public per env; its nginx proxies `/api` to the internal
gateway same-origin, so gateway and catalog are never exposed. All JVMs are
heap-capped and memory-limited.

## Layout

```
docker-compose.yml            one topology, fully driven by the per-env .env
environments/<env>/.env       version ledger (image digests) + tuning  [gitignored]
environments/<env>/secrets/   resolved config + Kafka CA, 600 perms     [gitignored]
edge/                         Caddy reverse proxy (shared) + Caddyfile
host/bootstrap.sh             one-time VPS hardening (Phase 1)
host/data-ingestion.cron.*    host trigger for the ingestion batch
scripts/deploy-service.sh     surgical single-service rollout (CI calls this)
scripts/staging.sh            staging up | down | status
scripts/ingest.sh             run the ingestion batch once
```

## How a deploy works

Each `*-cd` repo stays the source of truth for *its* live version. On release,
its `deploy.yml` computes the image digest and (instead of pushing to Render)
SSHes to the box and runs:

```bash
scripts/deploy-service.sh <env> <service> <sha256:digest>
```

That rewrites the one `*_DIGEST` line in `environments/<env>/.env`, pulls, and
`docker compose up -d --no-deps <service>` — recreating only that container.
Health-gated, with automatic rollback of the pin on failure. Siblings never
restart.

**Topology changes** (adding a service, changing mem limits) are edits to
`docker-compose.yml` in *this* repo, applied with a full `up -d`. A brand-new
service therefore lands here first (reviewed), then its `-cd` deploy pins the
digest.

## First bring-up

1. `host/bootstrap.sh <ssh-pubkey>` on the fresh VPS (hardening, Docker, swap, edge network).
2. Put this repo at `/opt/citypulse/platform-infrastructure`; `docker login ghcr.io` (read PAT).
3. Copy each `.env.example` → `.env`, fill `environments/<env>/secrets/`, and `edge/.env`.
4. `docker compose --env-file edge/.env -p citypulse-edge up -d`
5. `docker compose --env-file environments/prod/.env -p citypulse-prod up -d`
6. Staging on demand: `scripts/staging.sh up` / `down`.

## Environments & isolation

| Layer            | prod                     | staging                        |
|------------------|--------------------------|--------------------------------|
| compose project  | `citypulse-prod`         | `citypulse-staging`            |
| Docker network   | `citypulse-prod_internal`| `citypulse-staging_internal`   |
| Postgres (Aiven) | `citypulse_catalog`      | `citypulse_catalog_staging`    |
| Kafka topics/grp | prod topics + group      | staging topics + **own group** |
| secret set       | PRD                      | HPR                            |
| RAM posture      | priority tenant          | tight; switchable off          |

Distinct Kafka consumer groups per env are mandatory — same group would let
staging steal prod's messages. Container/network isolation alone doesn't cover
the shared managed backends.

## Observability (off-box)

No Prometheus/Grafana on the VPS. One tiny **Grafana Alloy** (or Vector)
container per env ships container logs + host/JVM metrics to **Grafana Cloud**
(free tier); dashboards, storage, and alerting live there. Docker's json log
driver is capped (`bootstrap.sh`) so `/var` can't fill.

## Gateway redeploy vs frontend nginx

The frontend nginx uses a Docker `resolver` and holds the gateway upstream in a
variable, so it re-resolves the gateway's IP per request. A gateway rollout
(new container IP) needs no frontend reload.

## Phase-0 app changes (done)

- **Eureka removed** from api-gateway + catalog-service; gateway wired via
  `CATALOG_URI`. `discovery-server` retired.
- **data-ingestion** is a run-once batch
  (`spring.main.web-application-type=none` + clean exit code); its schedule
  lives in the host cron above.
