#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

status=0

while IFS= read -r service_name; do
  service_dir="$(service_abs_dir "${service_name}")"
  env_file="$(service_env_file "${service_name}")"

  echo "== ${service_name} =="

  if [[ ! -d "${service_dir}" ]]; then
    echo "MISSING repo dir: ${service_dir}"
    status=1
    continue
  fi

  if [[ ! -f "${service_dir}/compose.yaml" ]]; then
    echo "MISSING compose: ${service_dir}/compose.yaml"
    status=1
  else
    echo "OK compose: ${service_dir}/compose.yaml"
  fi

  if [[ -n "${env_file}" && ! -f "${service_dir}/${env_file}" ]]; then
    echo "WARN env file not found: ${service_dir}/${env_file}"
  elif [[ -n "${env_file}" ]]; then
    echo "OK env file: ${service_dir}/${env_file}"
  fi
done < <(list_target_services "$@")

exit "${status}"

