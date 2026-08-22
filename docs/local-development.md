# Local development

`dev` is **not** a deployed environment — it's your laptop. The VPS runs staging
+ prod only. Locally you run the services natively (hot reload) against local or
cloud backing services.

## Two ways to run locally

### Option A — native services against cloud dev backing (quickest)
Run each service with its `local` Spring profile / Vite dev server, pointed at a
dev database + Kafka (e.g. the Aiven/Confluent dev instances your
`application-local.yaml` already references):

```bash
# in each service repo
./mvnw spring-boot:run -Dspring-boot.run.profiles=local   # java services
npm run dev                                                # frontend (Vite)
```
No Docker needed. Downside: you depend on cloud backing being reachable.

### Option B — fully local backing (offline, reproducible)
Use `local/docker-compose.yml` in this repo to spin up **Postgres + Redpanda**
(Kafka + Schema Registry) on your machine, then run the services natively
against `localhost`:

```bash
docker compose -f local/docker-compose.yml -p citypulse-local up -d
```
Then set your services' `application-local.yaml` to:
- Postgres: `jdbc:postgresql://localhost:5432/citypulse_catalog` (user/pass `citypulse`)
- Kafka: `localhost:19092`
- Schema Registry: `http://localhost:18081`

Run order that works well: `catalog-service` (8081) → `api-gateway` (8080) →
`frontend` (Vite proxies `/api` to the gateway). `data-ingestion` you run
on demand (it's a batch).

> The starter compose is a template — adjust ports if they clash with something
> you already run, and mirror those ports in `application-local.yaml`.

## Does the local env need to be on GitHub? Where?

**Yes, version it — and put it in THIS repo (`platform-infrastructure`), under
`local/`.** Reasoning:

- **Version it** so every developer (and future-you) gets the same local setup;
  a local compose that only lives on one laptop drifts and gets lost.
- **This repo, not a new one** — it's cross-service infrastructure, exactly what
  `platform-infrastructure` already owns (like `edge/`, `observability/`). A
  separate repo would be overkill and split infra across two places.
- **Not in a service repo** — it spans all services, so no single service repo
  is the right home.
- **It is never deployed** — `local/` is purely a developer convenience. It rides
  along in the repo but no pipeline touches it, and nothing on the VPS uses it.

So: commit `local/docker-compose.yml` here, and that's all the "hosting" it
needs. Contrast with the real env files (`environments/<env>/.env`, secrets)
which are git-ignored and live only on the VPS — the local compose has no
secrets, so it's safe to commit as-is.

## Notes
- The local backing has throwaway data (a `pgdata` volume). `docker compose -f
  local/docker-compose.yml -p citypulse-local down -v` wipes it for a clean slate.
- Keep local ports distinct from the app ports (services listen on 8080/8081) —
  that's why Kafka/SR are published on 19092/18081 here.
