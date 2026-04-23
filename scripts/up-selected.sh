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

  if [[ ! -f "${service_dir}/compose.yaml" ]]; then
    echo "SKIP ${service_name}: compose.yaml not found"
    continue
  fi

  echo "== starting ${service_name} =="
  if [[ -n "${env_file}" && -f "${service_dir}/${env_file}" ]]; then
    docker compose -f "${service_dir}/compose.yaml" --env-file "${service_dir}/${env_file}" up -d
  else
    docker compose -f "${service_dir}/compose.yaml" up -d
  fi
done < <(list_target_services "$@")

