#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STACK_ENV_FILE="${STACK_ENV_FILE:-${REPO_ROOT}/stack.env.local}"
SERVICES_FILE="${SERVICES_FILE:-${REPO_ROOT}/repos/services.tsv}"

if [[ -f "${STACK_ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${STACK_ENV_FILE}"
  set +a
fi

STACK_ROOT="${STACK_ROOT:-/home/hiyori2023}"

load_services() {
  grep -v '^[[:space:]]*#' "${SERVICES_FILE}" | grep -v '^[[:space:]]*$'
}

resolve_service_row() {
  local service_name="$1"
  load_services | awk -F '\t' -v svc="${service_name}" '$1 == svc { print $0 }'
}

service_repo_dir() {
  local service_name="$1"
  resolve_service_row "${service_name}" | awk -F '\t' '{ print $2 }'
}

service_env_file() {
  local service_name="$1"
  resolve_service_row "${service_name}" | awk -F '\t' '{ print $3 }'
}

service_abs_dir() {
  local service_name="$1"
  local repo_dir
  repo_dir="$(service_repo_dir "${service_name}")"
  printf '%s/%s\n' "${STACK_ROOT}" "${repo_dir}"
}

list_target_services() {
  if [[ "$#" -gt 0 ]]; then
    printf '%s\n' "$@"
  elif [[ -n "${SERVICES:-}" ]]; then
    for service in ${SERVICES}; do
      printf '%s\n' "${service}"
    done
  else
    load_services | awk -F '\t' '{ print $1 }'
  fi
}

