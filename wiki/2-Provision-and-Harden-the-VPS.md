# 2 · Provision & Harden the VPS

Goal: a fresh Ubuntu box turned into a secured Docker host with the shared edge
network and app directory ready.

## 2.1 Order the box 🔧

Order the OVH VPS with the **Ubuntu 26.04 LTS** image. If OVH lets you attach an
SSH key at order time, attach your admin public key. Otherwise note the root
password OVH emails you. Record the **public IP**.

## 2.2 First login 🔧

```bash
ssh root@<VPS_IP>        # or ssh ubuntu@<VPS_IP>, per OVH's default
```

## 2.3 Run the bootstrap script 🔧

Copy this repo's `host/bootstrap.sh` to the box (or paste it), then run it **as
root**, passing your admin SSH **public** key:

```bash
bash bootstrap.sh "ssh-ed25519 AAAA...yourkey you@host"
```

It is re-runnable. It performs, in order:

1. Base packages (`ufw`, `fail2ban`, `unattended-upgrades`, …).
2. Creates the **`deployer`** sudo user and installs your public key.
3. **Hardens SSH** — key-only, root login disabled.
4. **Firewall** — denies all inbound except **22 / 80 / 443**.
5. `fail2ban` + automatic security updates.
6. **4 GB swap** file with low swappiness (OOM insurance on 4 GB RAM).
7. Installs **Docker Engine + compose plugin**; caps container log size.
8. Creates the shared **`citypulse-edge`** Docker network and `/opt/citypulse`.

> ⚠️ After this runs, **root SSH and password login are disabled**. Reconnect as
> `deployer` with your key:
> ```bash
> ssh deployer@<VPS_IP>
> ```
> Keep your current root session open until you've confirmed the `deployer`
> login works, so you can't lock yourself out.

## 2.4 Authenticate to GHCR 🔧

So the box can pull the private images:

```bash
echo "<GHCR_READ_PAT>" | docker login ghcr.io -u <your-github-user> --password-stdin
```

## 2.5 Put the repo on the box

```bash
sudo chown -R deployer:deployer /opt/citypulse
cd /opt/citypulse
git clone <your platform-infrastructure remote> platform-infrastructure
cd platform-infrastructure
```

(If you version it privately, `scp`/`rsync` the directory here instead.)

## 2.6 Verify

```bash
docker network ls | grep citypulse-edge     # edge network exists
docker compose version                       # compose plugin present
swapon --show                                # swap active
sudo ufw status                              # 22/80/443 only
```

Next: [Secrets & Configuration →](3-Secrets-and-Configuration.md)
