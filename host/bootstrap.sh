#!/usr/bin/env bash
# One-time host preparation for a fresh Ubuntu 26.04 OVH VPS.
#
# READ IT before running — it changes SSH, the firewall, and installs Docker.
# Run as root on the box:  bash bootstrap.sh <your-ssh-public-key>
#
# It is written to be re-runnable (idempotent-ish): safe to run again if a step
# failed partway. It does NOT deploy the app — that's the compose stacks.
set -euo pipefail

DEPLOY_USER="deployer"
PUBKEY="${1:?pass your SSH public key as the first argument}"

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

# A fresh cloud image often races the unattended-upgrades / apt-daily timer for
# the dpkg lock; make apt wait for it rather than failing.
APT_WAIT="-o DPkg::Lock::Timeout=600"

echo "== 1/9 base packages =="
export DEBIAN_FRONTEND=noninteractive
apt-get $APT_WAIT update -y
apt-get $APT_WAIT install -y ca-certificates curl gnupg ufw fail2ban unattended-upgrades

echo "== 2/9 non-root sudo user with your key =="
id "$DEPLOY_USER" &>/dev/null || adduser --disabled-password --gecos "" "$DEPLOY_USER"
usermod -aG sudo "$DEPLOY_USER"
# The account is key-only (no password), so a sudo password prompt would be
# unusable. Login by SSH key already grants full admin on this single-admin box,
# so grant passwordless sudo rather than leaving sudo broken.
echo "$DEPLOY_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$DEPLOY_USER"
chmod 440 "/etc/sudoers.d/$DEPLOY_USER"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
echo "$PUBKEY" > "/home/$DEPLOY_USER/.ssh/authorized_keys"
chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"
chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh/authorized_keys"

echo "== 3/9 SSH hardening (key-only, no root) =="
install -d /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/10-citypulse.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
systemctl reload ssh || systemctl reload sshd

echo "== 4/9 firewall: only 22/80/443 inbound =="
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "== 5/9 fail2ban + automatic security updates =="
systemctl enable --now fail2ban
dpkg-reconfigure -f noninteractive unattended-upgrades || true

echo "== 6/9 swap (4 GB, low swappiness) — OOM insurance on 4 GB RAM =="
if ! swapon --show | grep -q '/swapfile'; then
  fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
  chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
sysctl -w vm.swappiness=10
echo 'vm.swappiness=10' > /etc/sysctl.d/99-citypulse.conf

echo "== 7/9 Docker Engine + compose plugin =="
if ! command -v docker &>/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get $APT_WAIT update -y
  apt-get $APT_WAIT install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
usermod -aG docker "$DEPLOY_USER"
# Cap container log growth so /var doesn't fill (logs are also shipped off-box).
cat > /etc/docker/daemon.json <<'EOF'
{ "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "3" } }
EOF
systemctl enable --now docker
systemctl restart docker

echo "== 8/9 shared edge network + app directory =="
docker network inspect citypulse-edge &>/dev/null || docker network create citypulse-edge
install -d -o "$DEPLOY_USER" -g "$DEPLOY_USER" /opt/citypulse

echo "== 9/9 done =="
cat <<EOF

Next:
  1. Log in as ${DEPLOY_USER} (root SSH is now disabled).
  2. Clone platform-infrastructure into /opt/citypulse (or rsync it there).
  3. docker login ghcr.io   (read-only PAT, so the box can pull private images)
  4. Fill environments/<env>/.env and environments/<env>/secrets/, and edge/.env
  5. Bring up edge, then prod:
       docker compose --env-file edge/.env -p citypulse-edge up -d
       docker compose --env-file environments/prod/.env -p citypulse-prod up -d
EOF
