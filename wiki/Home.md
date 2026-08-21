# CityPulse Platform Infrastructure — Wiki

Operator guide for standing up and running CityPulse on a single OVH VPS with
`platform-infrastructure`. Follow the pages in order for a first-time setup;
come back to Operations / Troubleshooting / Reference day to day.

> Legend: 🔧 **Manual step** = a human action outside this repo (ordering the
> VPS, creating credentials, DNS, running privileged commands on the box).
> Everything else is a command you run from the repo checkout on the VPS.

## Setup path (first time)

1. [Prerequisites](1-Prerequisites.md) — what you must have before you start.
2. [Provision & Harden the VPS](2-Provision-and-Harden-the-VPS.md) — order the box, run `bootstrap.sh`.
3. [Secrets & Configuration](3-Secrets-and-Configuration.md) — the `.env` and `secrets/` model.
4. [Backing Services](4-Backing-Services.md) — Aiven Postgres + Confluent Kafka, per environment.
5. [First Deployment](5-First-Deployment.md) — bring up edge, then prod, then staging.
6. [DNS & TLS](6-DNS-and-TLS.md) — hostnames and certificates (domain comes last).

## Running it

- [Day-to-Day Operations](7-Day-to-Day-Operations.md) — deploy a service, staging on/off, run ingestion, topology changes.
- [Troubleshooting](8-Troubleshooting.md) — common failures and fixes.
- [Reference](9-Reference.md) — env-var contract, secret files, ports, command cheat sheet.
- [Observability](10-Observability.md) — ship logs + metrics to Grafana Cloud.

## What this runs

One 4 GB VPS hosts **staging + production** side by side, each an isolated
Docker Compose project. Only each environment's **frontend** is public (via a
shared Caddy reverse proxy); the gateway and catalog service stay internal, and
`data-ingestion` is a run-once batch fired by host cron. Postgres (Aiven) and
Kafka (Confluent) are managed and off-box.

```
        Internet · 443
             │
          ┌──▼── Caddy ──┐          edge/  (always on, auto-TLS)
   prod host │           │ staging host
        ┌────▼────┐  ┌────▼─────┐    separate compose projects
        │ frontend│  │ frontend │    = separate Docker networks
        │  ↓ /api │  │  ↓ /api  │
        │ gateway │  │ gateway  │    internal only
        │  ↓      │  │  ↓       │
        │ catalog │  │ catalog  │
        │(ingest  │  │(ingest   │    batch: host cron → run → exit
        │ batch)  │  │ batch)   │
        └────┬────┘  └────┬─────┘
             ▼            ▼
     Aiven Postgres · Confluent Kafka  (managed, off-box)
```

The design rationale behind all of this lives in
[`docs/VPS/vps-deployment-design.md`](../../docs/VPS/vps-deployment-design.md).
This wiki is the *how*; that doc is the *why*.
