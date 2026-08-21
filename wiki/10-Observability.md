# 10 · Observability

Logs and metrics ship **off the box** to Grafana Cloud (free tier). A single
shared **Grafana Alloy** agent (`observability/`) collects everything for all
environments and sends it out over HTTPS — nothing (Prometheus/Grafana/storage)
runs on the VPS, and there's no new inbound surface.

What it collects:
- **Logs** — every Docker container's stdout/stderr → Grafana Cloud **Loki**,
  labelled by `env` (compose project), `service`, and `container`.
- **Host metrics** — CPU, memory, disk, network (node exporter) → Grafana Cloud
  **Prometheus**. The key signals for a 4 GB box.
- **Per-container metrics** — CPU/memory per container (cAdvisor) → Prometheus.
  This is how you tune the JVM heap caps.

## Set up (once) 🔧

> Grafana Cloud's UI wording shifts over time; the labels below are the current
> ones, but look for the same concepts if they've moved.

### A. Create the account
Sign up at **grafana.com** → "Create free account". This provisions a **stack**
(a hosted Grafana + Loki + Prometheus). The free tier is plenty here (metrics,
~50 GB logs, 14-day retention).

### B. Get the Prometheus (metrics) connection details
1. On **grafana.com**, open your stack.
2. Find the **Prometheus** tile → **Send Metrics** (a.k.a. "Details").
3. Copy:
   - **Remote Write Endpoint** (ends in `/api/prom/push`) → `GRAFANA_CLOUD_PROM_URL`
   - **Username / Instance ID** (a number) → `GRAFANA_CLOUD_PROM_USER`

### C. Get the Loki (logs) connection details
1. Same stack → **Loki** tile → **Send Logs**.
2. Copy:
   - **URL** (ends in `/loki/api/v1/push`) → `GRAFANA_CLOUD_LOKI_URL`
   - **User** (a number) → `GRAFANA_CLOUD_LOKI_USER`

### D. Create ONE token for both (Access Policy)
The push pages each offer to "generate a token", but those are scoped to one
signal. We use a single token for both, so create an Access Policy:
1. **grafana.com → Administration → Access Policies** (org-level) → **Create access policy**.
2. Realm = your stack. Scopes: tick **`metrics:write`** and **`logs:write`**.
3. Create it → **Add token** → name it `citypulse-alloy`, pick an expiry (or none)
   → **Create**. Copy the token (starts `glc_…`) → `GRAFANA_CLOUD_TOKEN`.
   It's shown **once** — grab it now.

### E. Fill the env file and start the agent (on the box, as `deployer`)
```bash
cd /opt/citypulse/platform-infrastructure
cp observability/.env.example observability/.env
$EDITOR observability/.env        # paste the 5 values from B–D
docker compose --env-file observability/.env -f observability/docker-compose.yml \
  -p citypulse-observability up -d
```

### F. Confirm it's shipping
```bash
docker compose --env-file observability/.env -f observability/docker-compose.yml \
  -p citypulse-observability logs -f alloy
```
Healthy signs: no repeating `401/403` (auth) or `connection` errors. A `401`
means the token/user is wrong; a `404` usually means a push URL is off.

## Use it

In Grafana Cloud:
- **Logs** — Explore → Loki → filter `{env="citypulse-prod"}` (or `staging`),
  `service="catalog-service"`, etc.
- **Host** — import the **Node Exporter Full** dashboard.
- **Containers** — import a **cAdvisor** dashboard to see per-container memory
  (watch the JVMs against their `mem_limit`s).

## Notes

- Alloy is capped at 300 MB and idles well under that; fine alongside prod on
  4 GB. If memory gets tight, the cAdvisor exporter is the first thing to drop
  (edit `observability/config.alloy`).
- Pin `grafana/alloy:latest` to a specific `vX.Y.Z` in
  `observability/docker-compose.yml` once you've settled, for reproducibility.
- Everything is outbound on 443 — no firewall changes needed.

See also: [Reference](9-Reference.md) · [Troubleshooting](8-Troubleshooting.md)
