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
STACK_GITHUB_OWNER="${STACK_GITHUB_OWNER:-Arrumis}"
CLONE_PROTOCOL="${CLONE_PROTOCOL:-https}"

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

service_legacy_compose_file() {
  local service_name="$1"
  resolve_service_row "${service_name}" | awk -F '\t' '{ print $4 }'
}

service_abs_dir() {
  local service_name="$1"
  local repo_dir
  repo_dir="$(service_repo_dir "${service_name}")"
  printf '%s/%s\n' "${STACK_ROOT}" "${repo_dir}"
}

service_compose_file() {
  local service_name="$1"
  printf '%s/compose.yaml\n' "$(service_abs_dir "${service_name}")"
}

service_compose_args() {
  local service_name="$1"
  local service_dir
  local env_file

  service_dir="$(service_abs_dir "${service_name}")"
  env_file="$(service_env_file "${service_name}")"

  if [[ -n "${env_file}" && -f "${service_dir}/${env_file}" ]]; then
    printf -- "-f\n%s\n--env-file\n%s\n" "${service_dir}/compose.yaml" "${service_dir}/${env_file}"
  else
    printf -- "-f\n%s\n" "${service_dir}/compose.yaml"
  fi
}

legacy_compose_args() {
  local service_name="$1"
  local legacy_compose

  legacy_compose="$(service_legacy_compose_file "${service_name}")"
  if [[ -z "${legacy_compose}" || ! -f "${legacy_compose}" ]]; then
    return 1
  fi

  printf -- "-f\n%s\n" "${legacy_compose}"
}

run_new_compose() {
  local service_name="$1"
  shift
  mapfile -t compose_args < <(service_compose_args "${service_name}")
  docker compose "${compose_args[@]}" "$@"
}

run_legacy_compose() {
  local service_name="$1"
  shift
  mapfile -t compose_args < <(legacy_compose_args "${service_name}")
  docker compose "${compose_args[@]}" "$@"
}

service_repo_url() {
  local service_name="$1"
  local repo_dir
  repo_dir="$(service_repo_dir "${service_name}")"

  case "${CLONE_PROTOCOL}" in
    ssh)
      printf 'git@github.com:%s/%s.git\n' "${STACK_GITHUB_OWNER}" "${repo_dir}"
      ;;
    https)
      printf 'https://github.com/%s/%s.git\n' "${STACK_GITHUB_OWNER}" "${repo_dir}"
      ;;
    *)
      echo "Unsupported CLONE_PROTOCOL: ${CLONE_PROTOCOL}" >&2
      return 1
      ;;
  esac
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
