#!/usr/bin/env bash
set -euo pipefail

STACK_ROOT="${STACK_ROOT:-${HOME}/docker-stack}"
STACK_GITHUB_OWNER="${STACK_GITHUB_OWNER:-Arrumis}"
CLONE_PROTOCOL="${CLONE_PROTOCOL:-https}"
DOMAIN="${DOMAIN:-}"
ROOT_HOST="${ROOT_HOST:-}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
PUBLIC_SCHEME="${PUBLIC_SCHEME:-http}"
EXCLUDED_SERVICES="${EXCLUDED_SERVICES:-}"
OPENVPN_ADMIN_PASSWORD="${OPENVPN_ADMIN_PASSWORD:-}"
INSTALLER_DIR="${INSTALLER_DIR:-${STACK_ROOT}/docker-stack-installer}"
SKIP_INSTALL="${SKIP_INSTALL:-0}"
SKIP_VERIFY="${SKIP_VERIFY:-0}"

usage() {
  cat <<'EOF'
Usage: bootstrap-clean-ubuntu.sh [options]

Options:
  --domain <domain>              Base public domain, e.g. ponkotu.mydns.jp
  --root-host <host>             Root host served by WordPress (default: same as domain)
  --email <email>                Email address used by certbot metadata
  --public-scheme <http|https>   Public URL scheme used for generated app URLs
  --stack-root <path>            Parent directory where repos are cloned
  --owner <github-owner>         GitHub owner/user for the repos
  --protocol <https|ssh>         Clone protocol for sibling repos
  --exclude-services <list>      Space-separated services excluded from default runs
  --openvpn-admin-password <pw>  OpenVPN admin password to store in .env.local
  --skip-install                 Stop after repo/bootstrap/env preparation
  --skip-verify                  Skip final verify-stack.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --root-host)
      ROOT_HOST="$2"
      shift 2
      ;;
    --email)
      LETSENCRYPT_EMAIL="$2"
      shift 2
      ;;
    --public-scheme)
      PUBLIC_SCHEME="$2"
      shift 2
      ;;
    --stack-root)
      STACK_ROOT="$2"
      INSTALLER_DIR="${STACK_ROOT}/docker-stack-installer"
      shift 2
      ;;
    --owner)
      STACK_GITHUB_OWNER="$2"
      shift 2
      ;;
    --protocol)
      CLONE_PROTOCOL="$2"
      shift 2
      ;;
    --exclude-services)
      EXCLUDED_SERVICES="$2"
      shift 2
      ;;
    --openvpn-admin-password)
      OPENVPN_ADMIN_PASSWORD="$2"
      shift 2
      ;;
    --skip-install)
      SKIP_INSTALL=1
      shift
      ;;
    --skip-verify)
      SKIP_VERIFY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${DOMAIN}" ]]; then
  echo "--domain is required" >&2
  exit 1
fi

if ! grep -qi 'ubuntu' /etc/os-release 2>/dev/null; then
  echo "This bootstrap script currently supports Ubuntu hosts." >&2
  exit 1
fi

ROOT_HOST="${ROOT_HOST:-${DOMAIN}}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@${DOMAIN}}"

sudo -v

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y ca-certificates curl git docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker "${USER}"

mkdir -p "${STACK_ROOT}"

if [[ ! -d "${INSTALLER_DIR}/.git" ]]; then
  case "${CLONE_PROTOCOL}" in
    ssh)
      git clone "git@github.com:${STACK_GITHUB_OWNER}/docker-stack-installer.git" "${INSTALLER_DIR}"
      ;;
    https)
      git clone "https://github.com/${STACK_GITHUB_OWNER}/docker-stack-installer.git" "${INSTALLER_DIR}"
      ;;
    *)
      echo "Unsupported clone protocol: ${CLONE_PROTOCOL}" >&2
      exit 1
      ;;
  esac
else
  git -C "${INSTALLER_DIR}" pull --ff-only
fi

cat >"${INSTALLER_DIR}/stack.env.local" <<EOF
STACK_ROOT=${STACK_ROOT}
STACK_GITHUB_OWNER=${STACK_GITHUB_OWNER}
CLONE_PROTOCOL=${CLONE_PROTOCOL}
EXCLUDED_SERVICES="${EXCLUDED_SERVICES}"
EOF

run_with_docker_group() {
  local command_string="$1"
  if docker info >/dev/null 2>&1; then
    bash -lc "${command_string}"
  else
    sg docker -c "${command_string}"
  fi
}

repo_cmd_prefix="cd '${INSTALLER_DIR}'"
configure_cmd="${repo_cmd_prefix} && ./scripts/configure-default-envs.sh --domain '${DOMAIN}' --root-host '${ROOT_HOST}' --email '${LETSENCRYPT_EMAIL}' --public-scheme '${PUBLIC_SCHEME}' --excluded-services '${EXCLUDED_SERVICES}'"
if [[ -n "${OPENVPN_ADMIN_PASSWORD}" ]]; then
  configure_cmd="${configure_cmd} --openvpn-admin-password '${OPENVPN_ADMIN_PASSWORD}'"
fi

run_with_docker_group "${repo_cmd_prefix} && ./scripts/bootstrap-repos.sh"
run_with_docker_group "${repo_cmd_prefix} && ./scripts/init-env-files.sh"
run_with_docker_group "${configure_cmd}"
run_with_docker_group "${repo_cmd_prefix} && ./scripts/doctor.sh"

if [[ "${SKIP_INSTALL}" -eq 0 ]]; then
  run_with_docker_group "${repo_cmd_prefix} && ./scripts/install-full-stack.sh --skip-bootstrap --skip-init-env"
  if [[ "${SKIP_VERIFY}" -eq 0 ]]; then
    run_with_docker_group "${repo_cmd_prefix} && ./scripts/verify-stack.sh"
  fi
fi

cat <<EOF
Bootstrap finished.

Installer repo:
  ${INSTALLER_DIR}

Next useful commands:
  cd ${INSTALLER_DIR}
  ./scripts/install-full-stack.sh --skip-bootstrap --skip-init-env
  ./scripts/verify-stack.sh
EOF
