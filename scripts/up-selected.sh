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
  run_new_compose "${service_name}" up -d
done < <(list_target_services "$@")
