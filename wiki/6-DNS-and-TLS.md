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

You don't need to buy the domain to get a working box for testing. Pick one:

- **Caddy internal CA (recommended pre-domain)** — add `tls internal` to each
  site block in `edge/Caddyfile` (self-signed, no ACME). Reachable over HTTPS
  with `curl -k` / a browser trust exception. Always works, no external
  dependency:
  ```
  {$PROD_APP_HOST} {
  	import common
  	tls internal
  	reverse_proxy frontend-prod:8080
  }
  ```

- **Bypass the proxy entirely** — to prove the app chain without any TLS, hit the
  frontend on the edge network directly:
  ```bash
  docker run --rm --network citypulse-edge curlimages/curl -fsS \
    http://frontend-prod:8080/api/v1/categories
  ```

> ⚠️ **`nip.io` does not reliably get a Let's Encrypt cert.** It's one shared
> registered domain, so LE's per-domain rate limits are usually already hit and
> issuance fails with a TLS `internal error`. Use it only for DNS resolution with
> `tls internal`, not for a public cert. Real certs come from your **own domain**
> below.

## When you buy the real domain 🔧

1. Create **A records** for both hostnames pointing at the VPS public IP.
2. Update `edge/.env` with the real hostnames and `ALLOWED_ORIGINS` in each
   `environments/<env>/.env`.
3. Reload:
   ```bash
   docker compose --env-file edge/.env -f edge/docker-compose.yml -p citypulse-edge up -d
   docker compose --env-file environments/prod/.env -p citypulse-prod up -d --no-deps api-gateway
   ```
   Caddy fetches the certificates on first request to each new hostname.

> Caddy's cert store lives in the `caddy_data` volume — the one piece of state on
> the box worth keeping. It auto-renews.

Next: [Day-to-Day Operations →](7-Day-to-Day-Operations.md)
