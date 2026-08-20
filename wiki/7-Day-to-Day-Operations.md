# 7 · Day-to-Day Operations

All commands run from `/opt/citypulse/platform-infrastructure` as `deployer`.

## Deploy a new version of one service

The surgical rollout — rewrites one digest pin, recreates only that container,
health-gates it, rolls back on failure. Siblings keep running.

```bash
scripts/deploy-service.sh prod catalog-service sha256:<new-digest>
```

- `<env>`: `prod` | `staging`
- `<service>`: `api-gateway` | `catalog-service` | `data-ingestion` | `frontend`
- `<digest>`: immutable `sha256:...` (see
  [Secrets & Configuration §3.1](3-Secrets-and-Configuration.md) for how to get one)

Deploying `data-ingestion` only re-pins its digest (it has no running container).

> After **Phase 3**, each service's `*-cd` `deploy.yml` calls this over SSH; you
> won't run it by hand for routine releases.

## Change the topology

Adding a service, changing a memory/CPU cap, or editing wiring means editing
`docker-compose.yml`, then reconciling the whole stack:

```bash
docker compose --env-file environments/prod/.env -p citypulse-prod up -d
```

A **brand-new** service must be added here first, then have its digest pinned by
a `deploy-service.sh` call.

## Staging on / off

```bash
scripts/staging.sh up        # bring staging up for testing
scripts/staging.sh status
scripts/staging.sh down      # stop it; hands all RAM back to prod
```

## Run the ingestion batch

```bash
scripts/ingest.sh prod       # runs once, exits
```

The scheduled run is the host cron installed in
[First Deployment §5.4](5-First-Deployment.md).

## Logs

```bash
# live tail for a service
docker compose --env-file environments/prod/.env -p citypulse-prod logs -f api-gateway

# last ingestion run
tail -n 100 /var/log/citypulse/ingest-prod.log
```

## Restart / recreate a service

```bash
docker compose --env-file environments/prod/.env -p citypulse-prod restart catalog-service
docker compose --env-file environments/prod/.env -p citypulse-prod up -d --no-deps --force-recreate catalog-service
```

## Update config or a secret

Edit the file under `environments/<env>/secrets/`, then recreate the consuming
service so it re-reads the mount:

```bash
docker compose --env-file environments/prod/.env -p citypulse-prod up -d --no-deps --force-recreate catalog-service
```

## Update the edge / Caddy

```bash
$EDITOR edge/Caddyfile     # or edge/.env
docker compose --env-file edge/.env -p citypulse-edge up -d
```

Next: [Troubleshooting →](8-Troubleshooting.md)
