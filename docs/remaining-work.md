# Remaining work

The migration is complete (prod + staging live, CD, observability). These are
the optional/last items, so they aren't forgotten.

## 1. Real domain (the planned "last" step)

Currently on `nip.io`. To move to your own domain:

1. Buy the domain.
2. Create **A records** for both hostnames → the VPS public IP (`92.222.86.47`):
   - `citypulse.<domain>` → prod
   - `staging.citypulse.<domain>` → staging
3. Update `edge/.env` on the box: `PROD_APP_HOST`, `STAGING_APP_HOST` (drop the
   `nip.io` values), and set `ACME_EMAIL` if not already real.
4. Update `ALLOWED_ORIGINS` in `environments/prod/.env` and
   `environments/staging/.env` to the new hostnames.
5. Recreate edge + gateways so the changes take:
   ```bash
   docker compose --env-file edge/.env -f edge/docker-compose.yml -p citypulse-edge up -d
   docker compose --env-file environments/prod/.env    -p citypulse-prod    up -d --no-deps api-gateway
   docker compose --env-file environments/staging/.env -p citypulse-staging up -d --no-deps api-gateway
   ```
6. Caddy fetches **real Let's Encrypt certs** on the first request to each new
   hostname (nip.io's cert problem goes away — it was a shared-domain rate limit).

## 2. Phase 6 — staging on/off automation (nice-to-have)

`scripts/staging.sh up|down` already works by hand. To make prod own the box by
default, automate the `down`:

- **Simplest:** a host cron as `deployer` that stops staging nightly:
  ```
  0 2 * * *  cd /opt/citypulse/platform-infrastructure && scripts/staging.sh down >> /var/log/citypulse/staging.log 2>&1
  ```
  Bring it back on demand with `scripts/staging.sh up`.
- **Or** a `workflow_dispatch` GitHub Action (staging up/down over SSH), if you
  prefer clicking a button to SSHing.

## 3. Tidies (housekeeping)

- **Gateway `/actuator/health` → 503 red herring.** The gateway has a Redis
  health indicator that's DOWN (no Redis on the `memory` rate-limit backend).
  Fix in the **api-gateway** repo: add `management.health.redis.enabled: false`
  to the default `application.yaml` (the local profile already has it). Cosmetic
  — routing and readiness are unaffected — but it stops the noisy 503.
- **Remove `deploy-render.yml`** from `deployment-workflows` (all `-cd` repos are
  on `deploy-vps.yml` now) and **retire the `RENDER_*` secrets/variables**
  (`RENDER_API_KEY`, `RENDER_SERVICE_ID_*`). Nothing references them.
- **Pin `grafana/alloy:latest`** to a specific `vX.Y.Z` in
  `observability/docker-compose.yml` for reproducibility.

## Not doing (decided against, for reference)

- **Self-hosted CI runner on the VPS** — considered to avoid SSH-from-Actions
  hitting sshd `MaxStartups` under the port-22 bot flood. Deferred; mitigated
  instead with `MaxStartups 100:30:200`. Revisit if deploys start failing on
  SSH resets.
