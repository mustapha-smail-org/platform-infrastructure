# 8 · Troubleshooting

Start with the logs of the affected service, then match the symptom below.

```bash
docker compose --env-file environments/<env>/.env -p citypulse-<env> ps
docker compose --env-file environments/<env>/.env -p citypulse-<env> logs --tail=200 <service>
```

## A container keeps restarting / exit code 137

**OOM-killed.** The JVM heap exceeded the container `mem_limit`.

- Check the caps in `environments/<env>/.env` (`*_MEM_LIMIT`, `*_JAVA_OPTS`).
  Heap is `MaxRAMPercentage` of `mem_limit`; keep `mem_limit` ≈ 1.6× the heap.
- If prod **and** staging are both up, the box may be over-committed — run
  `scripts/staging.sh down` and confirm. `free -m` / `docker stats` show pressure.

## A service never becomes healthy (deploy rolls back)

`deploy-service.sh` rolled the digest back because readiness never passed.

- Read the new container's logs (above) — usually a bad datasource/Kafka
  credential or an unreachable backing service.
- Confirm the mounted config resolved: `grep -R '%%SECRET:' environments/<env>/secrets/`
  must return nothing.
- Check the box can reach Aiven/Confluent (egress on 443/relevant ports).

## Caddy returns 502

- The target frontend isn't running. For staging that's expected when it's
  `down`. For prod, check `frontend` is up and healthy.
- Confirm the frontend is on the `citypulse-edge` network with the right alias
  (`frontend-prod` / `frontend-staging`).

## API calls 502 / 504 through the frontend

- The frontend proxies `/api` to `api-gateway:8080` on the internal network.
  Confirm the gateway is healthy and both are in the same compose project.
- The gateway proxies to `catalog-service:8080`; check catalog health too.

## TLS certificate not issued

- The hostname must resolve to the VPS IP (A record or `nip.io`), and inbound
  **80** must be open (`ufw status`) — Let's Encrypt validates over HTTP.
- Check Caddy logs:
  `docker compose --env-file edge/.env -f edge/docker-compose.yml -p citypulse-edge logs caddy`.
- Hitting Let's Encrypt rate limits? Use the staging ACME CA (commented in
  `edge/Caddyfile`) while iterating.

## Image won't pull

- `docker login ghcr.io` may have expired — re-run with a valid read PAT.
- The `*_DIGEST` in `.env` must be a real, pushed `sha256:...` for that repo.

## A secret path is a directory / `cp: cannot overwrite directory`

You ran `up` **before** the secret files existed. Docker creates a bind-mount
source as an empty **directory** (owned by `root`) when it's missing. Stop the
stack, remove the bogus directories, then place the real files:

```bash
docker compose --env-file environments/<env>/.env -p citypulse-<env> down
ls -la environments/<env>/secrets/          # spot the directories
sudo rm -rf environments/<env>/secrets/<name>   # each wrong entry
# create the real files, then:
sudo chown deployer:deployer environments/<env>/secrets/*
chmod 600 environments/<env>/secrets/*
```

Always have the secret files in place **before** the first `up` for an env.

## frontend exits: "app-config.json not found"

The frontend hard-fails without `/etc/secrets/app-config.json`. Ensure
`environments/<env>/secrets/app-config.json` exists (with a non-null
`API_GATEWAY_URL`) and is `chmod 600`.

## data-ingestion batch fails

- Run it in the foreground to see the error: `scripts/ingest.sh <env>`.
- Non-zero exit is by design on failure (so cron notices). Check Kafka/DB creds
  and the CA path (`/etc/secrets/ca.pem`).

## Locked out of SSH

You disabled root/password login in bootstrap. Use OVH's console/rescue mode to
fix `deployer`'s `~/.ssh/authorized_keys`. (Always confirm `deployer` login
works before closing your root session — see
[Provision & Harden §2.3](2-Provision-and-Harden-the-VPS.md).)

Next: [Reference →](9-Reference.md)
