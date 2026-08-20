# 5 · First Deployment

With the box hardened ([2](2-Provision-and-Harden-the-VPS.md)) and each env's
`.env` + `secrets/` filled ([3](3-Secrets-and-Configuration.md),
[4](4-Backing-Services.md)), bring the stack up. Order matters: **edge first**,
then prod, then staging.

All commands run from `/opt/citypulse/platform-infrastructure` as `deployer`.

## 5.1 Start the edge proxy

```bash
cp edge/.env.example edge/.env
$EDITOR edge/.env      # ACME_EMAIL + the two app hostnames (see DNS & TLS)
docker compose --env-file edge/.env -p citypulse-edge up -d
```

Until you own the domain, set the hosts to a temporary value — see
[DNS & TLS](6-DNS-and-TLS.md) for the `nip.io` and local-cert options.

## 5.2 Start production

```bash
docker compose --env-file environments/prod/.env -p citypulse-prod up -d
```

Watch it come healthy:

```bash
docker compose --env-file environments/prod/.env -p citypulse-prod ps
docker compose --env-file environments/prod/.env -p citypulse-prod logs -f api-gateway catalog-service
```

`data-ingestion` is **not** started here — it is a batch (see 5.4).

## 5.3 Verify

```bash
# frontend health, from the box
curl -fsS http://localhost/healthz            # via Caddy → prod frontend (once DNS/host resolves)
# or hit the frontend container's alias on the edge network:
docker run --rm --network citypulse-edge curlimages/curl -fsS http://frontend-prod:8080/healthz

# an API call proxied through the frontend to the gateway to catalog:
curl -fsS https://<prod-app-host>/api/v1/categories
```

If a container is unhealthy, jump to [Troubleshooting](8-Troubleshooting.md).

## 5.4 Schedule the ingestion batch 🔧

`data-ingestion` runs once and exits, on a host schedule — not inside the app.
Install the cron from the example:

```bash
sudo install -d -o deployer -g deployer /var/log/citypulse
crontab -e     # as deployer; paste the line from host/data-ingestion.cron.example
```

Run it once by hand to confirm it works end to end:

```bash
scripts/ingest.sh prod
```

## 5.5 Bring up staging (when you need it)

```bash
scripts/staging.sh up        # up | down | status
```

Staging is meant to be **off by default** so prod owns the box. Turn it on for a
test, off after:

```bash
scripts/staging.sh down      # returns staging's RAM to prod
```

Next: [DNS & TLS →](6-DNS-and-TLS.md)
