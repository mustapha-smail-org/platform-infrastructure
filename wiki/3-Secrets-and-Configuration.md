# 3 · Secrets & Configuration

Each environment is driven by two things on the box, **neither in git**:

- `environments/<env>/.env` — the non-secret knobs: which image digests are
  live, plus resource caps and wiring. This is the version ledger.
- `environments/<env>/secrets/` — the resolved config files and the Kafka CA,
  mounted into the containers.

Do this once per environment (`prod`, then `staging`).

## 3.1 The `.env` file

```bash
cd /opt/citypulse/platform-infrastructure
cp environments/prod/.env.example environments/prod/.env
$EDITOR environments/prod/.env
```

Most of it (project name, aliases, resource caps) is preset. The parts you set:

- `ALLOWED_ORIGINS` — the public app URL (placeholder until the domain exists).
- The four `*_DIGEST` lines — pin each image to an immutable digest.

**Getting a digest 🔧** for the tag you want to run:

```bash
docker pull ghcr.io/mustapha-smail-org/catalog-service:<tag>
docker inspect --format='{{index .RepoDigests 0}}' \
  ghcr.io/mustapha-smail-org/catalog-service:<tag>
# → ghcr.io/...@sha256:abc123...   copy the sha256:... part into CATALOG_SERVICE_DIGEST
```

(After Phase 3, CI writes these lines for you; for a manual bring-up you set
them by hand.)

## 3.2 The `secrets/` directory

```bash
mkdir -p environments/prod/secrets
chmod 700 environments/prod/secrets
```

Files it must contain (see `environments/prod/secrets/README.md`):

| File | Consumed by | Mounted at |
|------|-------------|------------|
| `application-catalog-service.yaml` | catalog-service | `/etc/secrets/application.yaml` |
| `application-data-ingestion.yaml` | data-ingestion | `/etc/secrets/application.yaml` |
| `app-config.json` | frontend | `/etc/secrets/app-config.json` |
| `kafka-ca.pem` | catalog + ingestion | `/etc/secrets/ca.pem` |

> The **api-gateway needs no file here** — it is driven entirely by env vars in
> `.env` (`CATALOG_URI`, `ALLOWED_ORIGINS`, `RATE_LIMIT_BACKEND`).

### Resolving the app config files 🔧

Each `application-<service>.yaml` is that service's `*-cd` repo file
`config/application-<env>.yaml` with every `%%SECRET:NAME%%` placeholder
replaced by the real value from your `PRD` (prod) / `HPR` (staging) secret set.
Do the substitution and drop the result in `secrets/`. A quick pattern:

```bash
# start from the -cd repo's config/application-production.yaml, then:
sed -e "s|%%SECRET:DATABASE_HOST%%|$DATABASE_HOST_PRD|g" \
    -e "s|%%SECRET:DATABASE_PASSWORD%%|$DATABASE_PASSWORD_PRD|g" \
    # ...one -e per placeholder... \
    application-production.yaml > environments/prod/secrets/application-catalog-service.yaml
```

Verify nothing is left unresolved:

```bash
grep -R '%%SECRET:' environments/prod/secrets/ && echo "UNRESOLVED!" || echo "clean"
```

### The frontend `app-config.json`

```json
{
  "API_GATEWAY_URL": "http://api-gateway:8080"
}
```

`API_GATEWAY_URL` points at the **internal** gateway (the frontend nginx proxies
`/api` to it). Add any browser-facing runtime keys the SPA expects alongside it.

### The Kafka CA

Write your Confluent CA certificate to `environments/prod/secrets/kafka-ca.pem`.

### Lock the permissions

```bash
chmod 600 environments/prod/secrets/*
```

## 3.3 Repeat for staging

Same steps with `environments/staging/…`, using the **`HPR`** secret set and the
staging database / topics / consumer group. See
[Backing Services](4-Backing-Services.md).

Next: [Backing Services →](4-Backing-Services.md)
