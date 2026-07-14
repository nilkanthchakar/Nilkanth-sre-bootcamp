#!/usr/bin/env bash
set -euo pipefail

install_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
}

install_docker_compose() {
  if ! command -v docker-compose >/dev/null 2>&1; then
    apt-get update
    apt-get install -y python3 python3-pip
    pip3 install docker-compose
  fi
}

install_git() {
  if ! command -v git >/dev/null 2>&1; then
    apt-get update
    apt-get install -y git
  fi
}

configure_sudo() {
  usermod -aG docker vagrant
}

main() {
  export DEBIAN_FRONTEND=noninteractive
  install_git
  install_docker
  install_docker_compose
  configure_sudo
  systemctl enable docker
  systemctl start docker
}

main "$@"
