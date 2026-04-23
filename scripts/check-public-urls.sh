#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

reverse_proxy_dir="$(service_abs_dir "infra-reverse-proxy")"
reverse_proxy_env="${reverse_proxy_dir}/$(service_env_file "infra-reverse-proxy")"

env_value() {
  local file_path="$1"
  local key="$2"
  local default_value="${3:-}"

  if [[ ! -f "${file_path}" ]]; then
    printf '%s\n' "${default_value}"
    return 0
  fi

  local value
  value="$(
    awk -F '=' -v target="${key}" '
      $0 !~ /^[[:space:]]*#/ && $1 == target {
        sub(/^[^=]*=/, "", $0)
        gsub(/^"|"$/, "", $0)
        print $0
        exit
      }
    ' "${file_path}"
  )"

  if [[ -n "${value}" ]]; then
    printf '%s\n' "${value}"
  else
    printf '%s\n' "${default_value}"
  fi
}

check_url() {
  local label="$1"
  local url="$2"

  if curl -fsSL --max-time 20 --retry 3 --retry-delay 2 --retry-connrefused "${url}" >/dev/null; then
    echo "OK ${label}: ${url}"
  else
    echo "NG ${label}: ${url}"
    return 1
  fi
}

domain="$(env_value "${reverse_proxy_env}" "DOMAIN" "example.local")"
root_host="$(env_value "${reverse_proxy_env}" "ROOT_HOST" "${domain}")"
ttrss_host="$(env_value "${reverse_proxy_env}" "TTRSS_HOST" "ttrss.${domain}")"
munin_host="$(env_value "${reverse_proxy_env}" "MUNIN_HOST" "munin.${domain}")"
tategaki_host="$(env_value "${reverse_proxy_env}" "TATEGAKI_HOST" "tategaki.${domain}")"
syncthing_host="$(env_value "${reverse_proxy_env}" "SYNCTHING_HOST" "syncthing.${domain}")"
openvpn_host="$(env_value "${reverse_proxy_env}" "OPENVPN_HOST" "openvpn.${domain}")"
traefik_host="$(env_value "${reverse_proxy_env}" "TRAEFIK_HOST" "traefik.${domain}")"
mirakurun_host="$(env_value "${reverse_proxy_env}" "MIRAKURUN_HOST" "mirakurun.${domain}")"
epgrec_host="$(env_value "${reverse_proxy_env}" "EPGREC_HOST" "epgrec.${domain}")"
epgstation_host="$(env_value "${reverse_proxy_env}" "EPGSTATION_HOST" "${epgrec_host}")"

check_url "wordpress" "https://${root_host}/"
check_url "ttrss" "https://${ttrss_host}/tt-rss/"
check_url "munin" "https://${munin_host}/"
check_url "tategaki" "https://${tategaki_host}/"
check_url "syncthing" "https://${syncthing_host}/"
check_url "openvpn" "https://${openvpn_host}/"
check_url "traefik" "https://${traefik_host}/dashboard/"
check_url "mirakurun" "https://${mirakurun_host}/"
check_url "epgrec" "https://${epgrec_host}/"
check_url "epgstation" "https://${epgstation_host}/"
