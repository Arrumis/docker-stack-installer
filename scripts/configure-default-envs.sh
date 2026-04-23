#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

DOMAIN="${DOMAIN:-}"
ROOT_HOST="${ROOT_HOST:-}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
PUBLIC_SCHEME="${PUBLIC_SCHEME:-http}"
OPENVPN_ADMIN_PASSWORD="${OPENVPN_ADMIN_PASSWORD:-}"
EXCLUDED_SERVICES_OVERRIDE="${EXCLUDED_SERVICES_OVERRIDE:-}"

usage() {
  cat <<'EOF'
Usage: ./scripts/configure-default-envs.sh [options]

Options:
  --domain <domain>              Base public domain, e.g. ponkotu.mydns.jp
  --root-host <host>             Root host served by WordPress (default: same as domain)
  --email <email>                Email address used by certbot metadata
  --public-scheme <http|https>   Public URL scheme used for generated app URLs
  --openvpn-admin-password <pw>  OpenVPN admin password to store in .env.local
  --excluded-services <list>     Space-separated services to store in stack.env.local
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
    --openvpn-admin-password)
      OPENVPN_ADMIN_PASSWORD="$2"
      shift 2
      ;;
    --excluded-services)
      EXCLUDED_SERVICES_OVERRIDE="$2"
      shift 2
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

ROOT_HOST="${ROOT_HOST:-${DOMAIN}}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@${DOMAIN}}"

random_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 32
    printf '\n'
  fi
}

env_get() {
  local file_path="$1"
  local key="$2"

  if [[ ! -f "${file_path}" ]]; then
    return 1
  fi

  awk -F '=' -v target="${key}" '
    $0 !~ /^[[:space:]]*#/ && $1 == target {
      sub(/^[^=]*=/, "", $0)
      print $0
      exit
    }
  ' "${file_path}"
}

env_set() {
  local file_path="$1"
  local key="$2"
  local value="$3"

  if [[ ! -f "${file_path}" ]]; then
    touch "${file_path}"
  fi

  if grep -qE "^${key}=" "${file_path}"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${file_path}"
  else
    printf '%s=%s\n' "${key}" "${value}" >>"${file_path}"
  fi
}

env_set_if_placeholder() {
  local file_path="$1"
  local key="$2"
  local fallback_value="$3"
  local current_value

  current_value="$(env_get "${file_path}" "${key}" || true)"
  case "${current_value}" in
    ""|change-me|change-me-root|example.local|admin@example.local|http://localhost:8280/tt-rss/)
      env_set "${file_path}" "${key}" "${fallback_value}"
      ;;
  esac
}

primary_interface() {
  ip route show default 2>/dev/null | awk '/default/ { print $5; exit }'
}

primary_ip() {
  ip route get 1.1.1.1 2>/dev/null | awk '
    {
      for (i = 1; i <= NF; i++) {
        if ($i == "src") {
          print $(i + 1)
          exit
        }
      }
    }
  '
}

HOST_IFACE="$(primary_interface || true)"
HOST_IP="$(primary_ip || true)"
HOST_SHORTNAME="$(hostname -s 2>/dev/null || hostname)"
MUNIN_PROXY_UPSTREAM="${HOST_IP:-127.0.0.1}:8081"

STACK_ENV_PATH="${STACK_ENV_FILE}"
if [[ -n "${EXCLUDED_SERVICES_OVERRIDE}" ]]; then
  env_set "${STACK_ENV_PATH}" "EXCLUDED_SERVICES" "\"${EXCLUDED_SERVICES_OVERRIDE}\""
fi

reverse_proxy_env="$(service_abs_dir "infra-reverse-proxy")/$(service_env_file "infra-reverse-proxy")"
env_set "${reverse_proxy_env}" "DOMAIN" "${DOMAIN}"
env_set "${reverse_proxy_env}" "ROOT_HOST" "${ROOT_HOST}"
env_set "${reverse_proxy_env}" "TTRSS_HOST" "ttrss.${DOMAIN}"
env_set "${reverse_proxy_env}" "MUNIN_HOST" "munin.${DOMAIN}"
env_set "${reverse_proxy_env}" "TATEGAKI_HOST" "tategaki.${DOMAIN}"
env_set "${reverse_proxy_env}" "SYNCTHING_HOST" "syncthing.${DOMAIN}"
env_set "${reverse_proxy_env}" "OPENVPN_HOST" "openvpn.${DOMAIN}"
env_set "${reverse_proxy_env}" "TRAEFIK_HOST" "traefik.${DOMAIN}"
env_set "${reverse_proxy_env}" "EPGREC_HOST" "epgrec.${DOMAIN}"
env_set "${reverse_proxy_env}" "EPGSTATION_HOST" "epgstation.${DOMAIN}"
env_set "${reverse_proxy_env}" "MIRAKURUN_HOST" "mirakurun.${DOMAIN}"
env_set "${reverse_proxy_env}" "WORDPRESS_UPSTREAM" "127.0.0.1:8080"
env_set "${reverse_proxy_env}" "TTRSS_UPSTREAM" "127.0.0.1:8280"
env_set "${reverse_proxy_env}" "MUNIN_UPSTREAM" "${MUNIN_PROXY_UPSTREAM}"
env_set "${reverse_proxy_env}" "TATEGAKI_UPSTREAM" "127.0.0.1:3000"
env_set "${reverse_proxy_env}" "SYNCTHING_UPSTREAM" "127.0.0.1:8384"
env_set "${reverse_proxy_env}" "OPENVPN_ADMIN_UPSTREAM" "127.0.0.1:943"
env_set "${reverse_proxy_env}" "OPENVPN_CLIENT_UPSTREAM" "127.0.0.1:9443"
env_set "${reverse_proxy_env}" "MIRAKURUN_UPSTREAM" "127.0.0.1:40772"
env_set "${reverse_proxy_env}" "EPGSTATION_UPSTREAM" "127.0.0.1:8888"
env_set "${reverse_proxy_env}" "TLS_CERT_NAME" "${ROOT_HOST}"
env_set "${reverse_proxy_env}" "LETSENCRYPT_EMAIL" "${LETSENCRYPT_EMAIL}"

wordpress_env="$(service_abs_dir "app-wordpress")/$(service_env_file "app-wordpress")"
env_set_if_placeholder "${wordpress_env}" "WORDPRESS_DB_PASSWORD" "$(random_secret)"
env_set_if_placeholder "${wordpress_env}" "MYSQL_ROOT_PASSWORD" "$(random_secret)"

ttrss_env="$(service_abs_dir "app-ttrss")/$(service_env_file "app-ttrss")"
env_set_if_placeholder "${ttrss_env}" "TTRSS_DB_PASS" "$(random_secret)"
env_set "${ttrss_env}" "TTRSS_SELF_URL_PATH" "${PUBLIC_SCHEME}://ttrss.${DOMAIN}/tt-rss/"

munin_env="$(service_abs_dir "infra-munin")/$(service_env_file "infra-munin")"
env_set "${munin_env}" "MUNIN_HTTP_PORT" "8081"
env_set "${munin_env}" "MUNIN_NODE_NAME" "${HOST_SHORTNAME}"
env_set "${munin_env}" "MUNIN_NODE_ADDRESS" "host.docker.internal"
env_set "${munin_env}" "MUNIN_ALLOWED_CIDR" "172.16.0.0/12"

syncthing_env="$(service_abs_dir "app-syncthing")/$(service_env_file "app-syncthing")"
env_set "${syncthing_env}" "HOSTNAME" "${HOST_SHORTNAME}"

openvpn_env="$(service_abs_dir "app-openvpn")/$(service_env_file "app-openvpn")"
if [[ -n "${HOST_IFACE}" ]]; then
  env_set "${openvpn_env}" "INTERFACE" "${HOST_IFACE}"
fi
if [[ -n "${OPENVPN_ADMIN_PASSWORD}" ]]; then
  env_set "${openvpn_env}" "OPENVPN_ADMIN_PASSWORD" "${OPENVPN_ADMIN_PASSWORD}"
else
  env_set_if_placeholder "${openvpn_env}" "OPENVPN_ADMIN_PASSWORD" "$(random_secret)"
fi

epg_env="$(service_abs_dir "app-mirakurun-epgstation")/$(service_env_file "app-mirakurun-epgstation")"
env_set_if_placeholder "${epg_env}" "EPG_DB_PASSWORD" "$(random_secret)"
env_set_if_placeholder "${epg_env}" "EPG_DB_ROOT_PASSWORD" "$(random_secret)"

cat <<EOF
Configured default env files for:
- domain: ${DOMAIN}
- root host: ${ROOT_HOST}
- public scheme: ${PUBLIC_SCHEME}
- host interface: ${HOST_IFACE:-unknown}
- host ip: ${HOST_IP:-unknown}
- munin upstream: ${MUNIN_PROXY_UPSTREAM}
EOF
