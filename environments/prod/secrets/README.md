# prod/secrets/ — resolved secret material (NOT in git)

Everything here is git-ignored. It is placed on the VPS at deploy time (by CI
over SSH, or by hand for the first bring-up) with strict perms:

    chmod 700 environments/prod/secrets
    chmod 600 environments/prod/secrets/*

Expected files (mounted into containers by `docker-compose.yml`):

| File                              | Mounted at                     | Used by         |
|-----------------------------------|--------------------------------|-----------------|
| `application-catalog-service.yaml`| `/etc/secrets/application.yaml` | catalog-service |
| `application-data-ingestion.yaml` | `/etc/secrets/application.yaml` | data-ingestion  |
| `app-config.json`                 | `/etc/secrets/app-config.json`  | frontend        |
| `kafka-ca.pem`                    | `/etc/secrets/ca.pem`           | catalog, ingest |

The `application-*.yaml` files are the `config/application-production.yaml`
from each `*-cd` repo with every `%%SECRET:NAME%%` placeholder already
substituted — the same resolution the CD pipeline did before pushing to Render,
now writing here instead. `app-config.json` must contain a non-null
`API_GATEWAY_URL` (set it to `http://api-gateway:8080` — the internal gateway).

The api-gateway needs no file here: it is driven entirely by env vars in
`../.env` (`CATALOG_URI`, `ALLOWED_ORIGINS`, `RATE_LIMIT_BACKEND`).
