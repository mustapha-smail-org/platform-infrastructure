# 1 · Prerequisites

Everything here is 🔧 **manual** — gather it before touching the box. None of it
is created by this repo.

## Accounts & access you need

| Item | Notes |
|------|-------|
| 🔧 OVH VPS | 2 vCPU / 4 GB / 40 GB NVMe, **Ubuntu 26.04 LTS** image. Note its public IP. |
| 🔧 SSH key (admin) | Your personal keypair. The **public** key is passed to `bootstrap.sh`; you log in as `deployer` with the matching private key. |
| 🔧 GHCR read token | A GitHub PAT with `read:packages`, so the box can pull the private `ghcr.io/mustapha-smail-org/*` images. Used once for `docker login ghcr.io`. |
| 🔧 Aiven Postgres | Existing cluster. You will add a **staging** database (prod DB already exists). |
| 🔧 Confluent Kafka | Existing cluster + Schema Registry. You will add **staging** topics and a distinct consumer group. |
| 🔧 Domain name | **Not required yet** — buy it last (see [DNS & TLS](6-DNS-and-TLS.md)). Until then use a `nip.io` host or Caddy's internal CA. |

## Secrets you must have on hand

These populate `environments/<env>/secrets/` (see
[Secrets & Configuration](3-Secrets-and-Configuration.md)). They already exist
as the `PRD` / `HPR` sets used by the old Render pipeline:

- Postgres: host, port, database, username, password
- Kafka: bootstrap servers, username, password, topics, **consumer group id**, CA certificate
- Schema Registry: url, username, password

> **Production uses the `PRD` set; staging uses the `HPR` set.** Staging must
> point at the staging database and staging topics with its **own** consumer
> group — never prod's.

## Tools on your workstation

- `ssh` / `scp` to reach the VPS.
- `git` to clone this repo (you version `platform-infrastructure` yourself).

## What you do NOT need yet

- The domain (buy it once everything works on a temporary host).
- The CI deploy key / GitHub Actions secrets — those belong to **Phase 3**
  (CD rewire). This wiki covers a **manual** first bring-up; automated
  deploys come later.

Next: [Provision & Harden the VPS →](2-Provision-and-Harden-the-VPS.md)
