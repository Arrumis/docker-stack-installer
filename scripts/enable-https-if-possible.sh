#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

AUTO_ENABLE_HTTPS="${AUTO_ENABLE_HTTPS:-1}"

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

case "${AUTO_ENABLE_HTTPS}" in
  1|true|TRUE|yes|YES)
    ;;
  *)
    echo "Skip automatic HTTPS enablement: AUTO_ENABLE_HTTPS=${AUTO_ENABLE_HTTPS}"
    exit 0
    ;;
esac

if ! service_requested "infra-reverse-proxy"; then
  echo "Skip automatic HTTPS enablement: infra-reverse-proxy is not in the target services."
  exit 0
fi

reverse_proxy_dir="$(service_abs_dir "infra-reverse-proxy")"
reverse_proxy_env="${reverse_proxy_dir}/$(service_env_file "infra-reverse-proxy")"

domain="$(env_value "${reverse_proxy_env}" "DOMAIN" "")"
root_host="$(env_value "${reverse_proxy_env}" "ROOT_HOST" "${domain}")"
letsencrypt_email="$(env_value "${reverse_proxy_env}" "LETSENCRYPT_EMAIL" "admin@${domain}")"

if [[ -z "${domain}" || "${domain}" == "example.local" ]]; then
  echo "Skip automatic HTTPS enablement: DOMAIN is not set to a public host."
  exit 0
fi

echo "== enabling HTTPS for ${domain} =="

if (
  cd "${reverse_proxy_dir}"
  ./scripts/request-certificates.sh
); then
  "${SCRIPT_DIR}/configure-default-envs.sh" \
    --domain "${domain}" \
    --root-host "${root_host}" \
    --email "${letsencrypt_email}" \
    --public-scheme https \
    --excluded-services "${EXCLUDED_SERVICES:-}"

  if service_requested "app-ttrss"; then
    echo "== restarting app-ttrss to apply https public URL =="
    run_new_compose "app-ttrss" up -d
  fi

  echo "Automatic HTTPS enablement completed."
else
  echo "WARN automatic HTTPS enablement failed; keeping HTTP mode."
fi
