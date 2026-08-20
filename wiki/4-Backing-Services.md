# 4 · Backing Services

Postgres (Aiven) and Kafka (Confluent) stay **managed and off the VPS**. Both
clusters are shared between environments; isolation is per-environment *inside*
each cluster. All steps here are 🔧 **manual**, done in the Aiven / Confluent
consoles.

> **Why this matters:** two isolated Docker stacks still corrupt each other if
> they share a database schema or a Kafka consumer group. This separation is the
> real environment boundary — container isolation alone does not provide it.

## 4.1 Postgres (Aiven) 🔧

| | production | staging |
|--|-----------|---------|
| Database | `citypulse_catalog` (exists) | `citypulse_catalog_staging` (create it) |
| Credentials | `PRD` set | `HPR` set |

- Create the staging database in the **same** Aiven cluster.
- catalog-service runs Flyway with `ddl-auto: validate`, so let it create/migrate
  the schema on first staging start (its migrations live in the image).

## 4.2 Kafka + Schema Registry (Confluent) 🔧

| | production | staging |
|--|-----------|---------|
| Topics | prod topic names | staging-suffixed topic names |
| Consumer group | prod group id | **distinct** staging group id |
| Credentials | `PRD` set | `HPR` set |

- Create the staging topics (and DLT if used) with a distinct prefix.
- Give staging its **own consumer group id**. If staging reused prod's group id,
  it would consume — and acknowledge — prod's messages.
- Schema Registry: reuse the cluster; staging subjects follow the staging topic
  names. `auto-register-schemas` is `false`, so register schemas as your process
  requires.

## 4.3 Where these values go

Every value above is already part of your `PRD` / `HPR` secret set and lands in
the resolved `secrets/application-*.yaml` files from
[Secrets & Configuration](3-Secrets-and-Configuration.md) — the Kafka CA goes in
`kafka-ca.pem`.

Next: [First Deployment →](5-First-Deployment.md)
