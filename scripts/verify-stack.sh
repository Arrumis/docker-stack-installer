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

https_active() {
  ss -tln | grep -qE '[:.]443[[:space:]]'
}

verify_reverse_proxy() {
  local domain
  local root_host
  local ttrss_host
  local munin_host

  domain="$(env_value "infra-reverse-proxy" "DOMAIN" "example.local")"
  root_host="$(env_value "infra-reverse-proxy" "ROOT_HOST" "${domain}")"
  ttrss_host="$(env_value "infra-reverse-proxy" "TTRSS_HOST" "ttrss.${domain}")"
  munin_host="$(env_value "infra-reverse-proxy" "MUNIN_HOST" "munin.${domain}")"

  if https_active; then
    check_curl "proxy wordpress https" curl -kfsSI -H "Host: ${root_host}" https://127.0.0.1/
    check_curl "proxy ttrss https" curl -kfsSI -H "Host: ${ttrss_host}" https://127.0.0.1/tt-rss/
    check_curl "proxy munin https" curl -kfsSI -H "Host: ${munin_host}" https://127.0.0.1/
  else
    check_curl "proxy wordpress http" curl -fsSI -H "Host: ${root_host}" http://127.0.0.1/
    check_curl "proxy ttrss http" curl -fsSI -H "Host: ${ttrss_host}" http://127.0.0.1/tt-rss/
    check_curl "proxy munin http" curl -fsSI -H "Host: ${munin_host}" http://127.0.0.1/
  fi
}

verify_service_ports() {
  local web_ui_port
  local admin_ui_port
  local openvpn_https_port
  local tategaki_port
  local txtmiru_port
  local favapi_port
  local mirakurun_port
  local epgstation_port

  web_ui_port="$(env_value "app-syncthing" "WEB_UI_PORT" "8384")"
  check_curl "syncthing web ui" curl -fsSI "http://127.0.0.1:${web_ui_port}/"

  admin_ui_port="$(env_value "app-openvpn" "ADMIN_UI_PORT" "943")"
  openvpn_https_port="$(env_value "app-openvpn" "HTTPS_PORT" "9443")"
  check_curl "openvpn admin" curl -kfsSI "https://127.0.0.1:${admin_ui_port}/admin"
  check_curl "openvpn client" curl -kfsSI "https://127.0.0.1:${openvpn_https_port}/"

  tategaki_port="$(env_value "app-tategaki" "APP_PORT" "3000")"
  check_curl "tategaki" curl -fsSI "http://127.0.0.1:${tategaki_port}/"

  txtmiru_port="$(env_value "app-txtmiru-with-narourb" "TXTMIRU_HTTP_PORT" "8081")"
  favapi_port="$(env_value "app-txtmiru-with-narourb" "FAVAPI_HTTP_PORT" "18080")"
  check_curl "txtmiru" curl -fsSI "http://127.0.0.1:${txtmiru_port}/"
  check_curl "favapi" curl -fsSI "http://127.0.0.1:${favapi_port}/docs"

  mirakurun_port="$(env_value "app-mirakurun-epgstation" "MIRAKURUN_PORT" "40772")"
  epgstation_port="$(env_value "app-mirakurun-epgstation" "EPGSTATION_PORT" "8888")"
  check_curl "mirakurun api" curl -fsS "http://127.0.0.1:${mirakurun_port}/api/version"
  check_curl "epgstation" curl -fsSI "http://127.0.0.1:${epgstation_port}/"
}

verify_reverse_proxy
verify_service_ports

exit "${verify_status}"
