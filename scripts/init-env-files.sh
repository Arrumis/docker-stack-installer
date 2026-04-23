#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

UNIFIED_ENV_EXAMPLE_FILE="${REPO_ROOT}/stack.service.env.example"

if [[ ! -f "${UNIFIED_ENV_FILE}" && -f "${UNIFIED_ENV_EXAMPLE_FILE}" ]]; then
  cp "${UNIFIED_ENV_EXAMPLE_FILE}" "${UNIFIED_ENV_FILE}"
  echo "CREATE unified env: ${UNIFIED_ENV_FILE} from ${UNIFIED_ENV_EXAMPLE_FILE}"
fi

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
    apply_unified_overrides_for_service "${service_name}"
    echo "KEEP ${service_name}: ${env_file} already exists"
    continue
  fi

  if [[ -f "${service_dir}/.env.example" ]]; then
    cp "${service_dir}/.env.example" "${service_dir}/${env_file}"
    apply_unified_overrides_for_service "${service_name}"
    echo "CREATE ${service_name}: ${env_file} from .env.example"
  else
    echo "SKIP ${service_name}: .env.example not found"
  fi
done < <(list_target_services "$@")
