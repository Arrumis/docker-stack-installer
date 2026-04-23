#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

while IFS= read -r service_name; do
  service_dir="$(service_abs_dir "${service_name}")"
  env_file="$(service_env_file "${service_name}")"

  if [[ ! -d "${service_dir}" ]]; then
    echo "SKIP ${service_name}: repo dir not found at ${service_dir}"
    continue
  fi

  if [[ -z "${env_file}" ]]; then
    echo "SKIP ${service_name}: env file is not configured"
    continue
  fi

  if [[ -f "${service_dir}/${env_file}" ]]; then
    echo "KEEP ${service_name}: ${env_file} already exists"
    continue
  fi

  if [[ -f "${service_dir}/.env.example" ]]; then
    cp "${service_dir}/.env.example" "${service_dir}/${env_file}"
    echo "CREATE ${service_name}: ${env_file} from .env.example"
  else
    echo "SKIP ${service_name}: .env.example not found"
  fi
done < <(list_target_services "$@")

