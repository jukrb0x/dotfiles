#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]] || ! grep -qi microsoft /proc/version; then
  echo "This script is intended for Ubuntu on WSL." >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get is required. This script currently supports Ubuntu/Debian WSL distributions." >&2
  exit 1
fi

target_user="${DOCKER_USER:-$USER}"
sudo_cmd=(sudo)

if [[ "$(id -u)" -eq 0 ]]; then
  sudo_cmd=()
  target_user="${DOCKER_USER:-${SUDO_USER:-}}"

  if [[ -z "$target_user" ]]; then
    target_user="$(getent passwd 1000 | cut -d: -f1)"
  fi

  if [[ -z "$target_user" ]]; then
    echo "Set DOCKER_USER to the WSL user that should be added to the docker group." >&2
    exit 1
  fi
fi

if ! command -v systemctl >/dev/null 2>&1 || ! systemctl is-system-running >/dev/null 2>&1; then
  echo "systemd is required for the managed Docker service in WSL." >&2
  echo "Enable it in /etc/wsl.conf, then run 'wsl.exe --shutdown' from Windows." >&2
  exit 1
fi

"${sudo_cmd[@]}" install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
  "${sudo_cmd[@]}" curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" -o /etc/apt/keyrings/docker.asc
  "${sudo_cmd[@]}" chmod a+r /etc/apt/keyrings/docker.asc
fi

. /etc/os-release

arch="$(dpkg --print-architecture)"
codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"

if [[ -z "$codename" ]]; then
  echo "Could not detect the Ubuntu codename from /etc/os-release." >&2
  exit 1
fi

"${sudo_cmd[@]}" tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $codename
Components: stable
Architectures: $arch
Signed-By: /etc/apt/keyrings/docker.asc
EOF

"${sudo_cmd[@]}" apt-get update
"${sudo_cmd[@]}" apt-get remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true
"${sudo_cmd[@]}" apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

"${sudo_cmd[@]}" systemctl enable --now docker
"${sudo_cmd[@]}" usermod -aG docker "$target_user"

echo "Docker Engine is installed and the docker service is enabled."
echo "Restart WSL or open a new login shell so the docker group membership is applied."
echo "Verify with: docker version && docker compose version && docker run --rm hello-world"
