# 6 · DNS & TLS

Caddy (the `edge` stack) terminates TLS and routes each public hostname to that
environment's frontend. Certificates are automatic (Let's Encrypt) once a real
hostname resolves to the box.

## The hostnames

Set in `edge/.env`:

```
ACME_EMAIL=you@example.com
PROD_APP_HOST=citypulse.example.com
STAGING_APP_HOST=staging.citypulse.example.com
```

Caddy routes `PROD_APP_HOST` → `frontend-prod:8080` and `STAGING_APP_HOST` →
`frontend-staging:8080` on the shared edge network.

## Before you own the domain

You don't need to buy the domain to get a working, HTTPS-capable box. Pick one:

- **`nip.io` (recommended for a real cert)** 🔧 — a free wildcard-DNS host that
  maps an IP into a name. Set, e.g.:
  ```
  PROD_APP_HOST=<VPS_IP>.nip.io
  STAGING_APP_HOST=staging-<VPS_IP-with-dashes>.nip.io
  ```
  These resolve to your box, so Let's Encrypt issues real certs.

- **Local / self-signed** — for testing without any public DNS, replace the site
  addresses in `edge/Caddyfile` with `:80` blocks and add `tls internal`
  (Caddy's own CA). No ACME, browser shows an untrusted cert. Fine for a smoke
  test, not for sharing.

## When you buy the real domain 🔧

1. Create **A records** for both hostnames pointing at the VPS public IP.
2. Update `edge/.env` with the real hostnames and `ALLOWED_ORIGINS` in each
   `environments/<env>/.env`.
3. Reload:
   ```bash
   docker compose --env-file edge/.env -p citypulse-edge up -d
   docker compose --env-file environments/prod/.env -p citypulse-prod up -d --no-deps api-gateway
   ```
   Caddy fetches the certificates on first request to each new hostname.

> Caddy's cert store lives in the `caddy_data` volume — the one piece of state on
> the box worth keeping. It auto-renews.

Next: [Day-to-Day Operations →](7-Day-to-Day-Operations.md)
