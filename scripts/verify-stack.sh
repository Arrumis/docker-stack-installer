#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required"
  exit 1
fi

if ! command -v ss >/dev/null 2>&1; then
  echo "ss is required"
  exit 1
fi

verify_status=0
VERIFY_RETRY_DELAY="${VERIFY_RETRY_DELAY:-2}"
mapfile -t target_services < <(list_target_services "$@")

service_requested() {
  local target="$1"
  local service_name

  for service_name in "${target_services[@]}"; do
    if [[ "${service_name}" == "${target}" ]]; then
      return 0
    fi
  done

  return 1
}

env_value() {
  local service_name="$1"
  local key="$2"
  local default_value="${3:-}"
  local service_dir
  local env_file

  service_dir="$(service_abs_dir "${service_name}")"
  env_file="$(service_env_file "${service_name}")"

  if [[ -n "${env_file}" && -f "${service_dir}/${env_file}" ]]; then
    local value
    value="$(
      awk -F '=' -v target="${key}" '
        $0 !~ /^[[:space:]]*#/ && $1 == target {
          sub(/^[^=]*=/, "", $0)
          print $0
          exit
        }
      ' "${service_dir}/${env_file}"
    )"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi
  fi
  printf '%s\n' "${default_value}"
}

check_curl() {
  local label="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    echo "OK ${label}"
  else
    echo "NG ${label}"
    verify_status=1
  fi
}

check_curl_with_retry() {
  local label="$1"
  local retries="$2"
  shift 2

  local attempt=1
  while (( attempt <= retries )); do
    if "$@" >/dev/null 2>&1; then
      echo "OK ${label}"
      return 0
    fi

    if (( attempt < retries )); then
      sleep "${VERIFY_RETRY_DELAY}"
    fi
    ((attempt++))
  done

  echo "NG ${label}"
  verify_status=1
}

https_active() {
  ss -tln | grep -qE '[:.]443[[:space:]]'
}

proxy_check_https() {
  local host="$1"
  local path="${2:-/}"
  curl -kfsSI --resolve "${host}:443:127.0.0.1" "https://${host}${path}"
}

proxy_check_http() {
  local host="$1"
  local path="${2:-/}"
  curl -fsSI --resolve "${host}:80:127.0.0.1" "http://${host}${path}"
}

verify_reverse_proxy() {
  local domain
  local root_host
  local ttrss_host
  local munin_host
  local tategaki_host
  local syncthing_host
  local openvpn_host
  local traefik_host
  local mirakurun_host
  local epgrec_host
  local epgstation_host

  domain="$(env_value "infra-reverse-proxy" "DOMAIN" "example.local")"
  root_host="$(env_value "infra-reverse-proxy" "ROOT_HOST" "${domain}")"
  ttrss_host="$(env_value "infra-reverse-proxy" "TTRSS_HOST" "ttrss.${domain}")"
  munin_host="$(env_value "infra-reverse-proxy" "MUNIN_HOST" "munin.${domain}")"
  tategaki_host="$(env_value "infra-reverse-proxy" "TATEGAKI_HOST" "tategaki.${domain}")"
  syncthing_host="$(env_value "infra-reverse-proxy" "SYNCTHING_HOST" "syncthing.${domain}")"
  openvpn_host="$(env_value "infra-reverse-proxy" "OPENVPN_HOST" "openvpn.${domain}")"
  traefik_host="$(env_value "infra-reverse-proxy" "TRAEFIK_HOST" "traefik.${domain}")"
  mirakurun_host="$(env_value "infra-reverse-proxy" "MIRAKURUN_HOST" "mirakurun.${domain}")"
  epgrec_host="$(env_value "infra-reverse-proxy" "EPGREC_HOST" "epgrec.${domain}")"
  epgstation_host="$(env_value "infra-reverse-proxy" "EPGSTATION_HOST" "${epgrec_host}")"

  if ! service_requested "infra-reverse-proxy"; then
    return 0
  fi

  if https_active; then
    if service_requested "app-wordpress"; then
      check_curl "proxy wordpress https" proxy_check_https "${root_host}" /
    fi
    if service_requested "app-ttrss"; then
      check_curl "proxy ttrss https" proxy_check_https "${ttrss_host}" /tt-rss/
    fi
    if service_requested "infra-munin"; then
      check_curl "proxy munin https" proxy_check_https "${munin_host}" /
    fi
    if service_requested "app-tategaki"; then
      check_curl "proxy tategaki https" proxy_check_https "${tategaki_host}" /
    fi
    if service_requested "app-syncthing"; then
      check_curl "proxy syncthing https" proxy_check_https "${syncthing_host}" /
    fi
    if service_requested "app-openvpn"; then
      check_curl "proxy openvpn https" proxy_check_https "${openvpn_host}" /
    fi
    check_curl "proxy traefik https" proxy_check_https "${traefik_host}" /dashboard/
    if service_requested "app-mirakurun-epgstation"; then
      check_curl_with_retry "proxy mirakurun https" 30 proxy_check_https "${mirakurun_host}" /
      check_curl_with_retry "proxy epgrec https" 30 proxy_check_https "${epgrec_host}" /
      check_curl_with_retry "proxy epgstation https" 30 proxy_check_https "${epgstation_host}" /
    fi
  else
    if service_requested "app-wordpress"; then
      check_curl "proxy wordpress http" proxy_check_http "${root_host}" /
    fi
    if service_requested "app-ttrss"; then
      check_curl "proxy ttrss http" proxy_check_http "${ttrss_host}" /tt-rss/
    fi
    if service_requested "infra-munin"; then
      check_curl "proxy munin http" proxy_check_http "${munin_host}" /
    fi
    if service_requested "app-tategaki"; then
      check_curl "proxy tategaki http" proxy_check_http "${tategaki_host}" /
    fi
    if service_requested "app-syncthing"; then
      check_curl "proxy syncthing http" proxy_check_http "${syncthing_host}" /
    fi
    if service_requested "app-openvpn"; then
      check_curl "proxy openvpn http" proxy_check_http "${openvpn_host}" /
    fi
    check_curl "proxy traefik http" proxy_check_http "${traefik_host}" /dashboard/
    if service_requested "app-mirakurun-epgstation"; then
      check_curl_with_retry "proxy mirakurun http" 30 proxy_check_http "${mirakurun_host}" /
      check_curl_with_retry "proxy epgrec http" 30 proxy_check_http "${epgrec_host}" /
      check_curl_with_retry "proxy epgstation http" 30 proxy_check_http "${epgstation_host}" /
    fi
  fi
}

verify_service_ports() {
  local web_ui_port
  local admin_ui_port
  local openvpn_https_port
  local tategaki_port
  local mirakurun_port
  local epgstation_port

  if service_requested "app-syncthing"; then
    web_ui_port="$(env_value "app-syncthing" "WEB_UI_PORT" "8384")"
    check_curl "syncthing web ui" curl -fsSI "http://127.0.0.1:${web_ui_port}/"
  fi

  if service_requested "app-openvpn"; then
    admin_ui_port="$(env_value "app-openvpn" "ADMIN_UI_PORT" "943")"
    openvpn_https_port="$(env_value "app-openvpn" "HTTPS_PORT" "9443")"
    check_curl "openvpn admin" curl -kfsSI "https://127.0.0.1:${admin_ui_port}/admin"
    check_curl "openvpn client" curl -kfsSI "https://127.0.0.1:${openvpn_https_port}/"
  fi

  if service_requested "app-tategaki"; then
    tategaki_port="$(env_value "app-tategaki" "APP_PORT" "3000")"
    check_curl "tategaki" curl -fsS "http://127.0.0.1:${tategaki_port}/"
  fi

  if service_requested "app-mirakurun-epgstation"; then
    mirakurun_port="$(env_value "app-mirakurun-epgstation" "MIRAKURUN_PORT" "40772")"
    epgstation_port="$(env_value "app-mirakurun-epgstation" "EPGSTATION_PORT" "8888")"
    check_curl_with_retry "mirakurun api" 30 curl -fsS "http://127.0.0.1:${mirakurun_port}/api/version"
    check_curl_with_retry "epgstation" 30 curl -fsSI "http://127.0.0.1:${epgstation_port}/"
  fi
}

verify_reverse_proxy
verify_service_ports

exit "${verify_status}"
