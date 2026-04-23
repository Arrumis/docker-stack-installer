#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

PULL_IMAGES=false
if [[ "${1:-}" == "--pull" ]]; then
  PULL_IMAGES=true
  shift
fi

status=0

while IFS= read -r service_name; do
  echo "== ${service_name} =="

  service_dir="$(service_abs_dir "${service_name}")"
  env_file="$(service_env_file "${service_name}")"

  if [[ ! -f "${service_dir}/compose.yaml" ]]; then
    echo "MISSING compose: ${service_dir}/compose.yaml"
    status=1
    echo
    continue
  fi

  if [[ -n "${env_file}" && ! -f "${service_dir}/${env_file}" ]]; then
    echo "MISSING env: ${service_dir}/${env_file}"
    status=1
    echo
    continue
  fi

  if run_new_compose "${service_name}" config >/dev/null; then
    echo "OK compose config"
  else
    echo "NG compose config"
    status=1
  fi

  if [[ "${PULL_IMAGES}" == "true" ]]; then
    if run_new_compose "${service_name}" pull >/dev/null; then
      echo "OK image pull"
    else
      echo "NG image pull"
      status=1
    fi
  fi

  echo
done < <(list_target_services "$@")

exit "${status}"

