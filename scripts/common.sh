#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STACK_ENV_FILE="${STACK_ENV_FILE:-${REPO_ROOT}/stack.env.local}"
UNIFIED_ENV_FILE="${UNIFIED_ENV_FILE:-${REPO_ROOT}/stack.service.env.local}"
SERVICES_FILE="${SERVICES_FILE:-${REPO_ROOT}/repos/services.tsv}"
LEGACY_SERVICES_FILE="${LEGACY_SERVICES_FILE:-${REPO_ROOT}/repos/legacy-services.local.tsv}"

if [[ -f "${STACK_ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${STACK_ENV_FILE}"
  set +a
fi

if [[ -f "${UNIFIED_ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${UNIFIED_ENV_FILE}"
  set +a
fi

STACK_ROOT="${STACK_ROOT:-$(cd "${REPO_ROOT}/.." && pwd)}"
STACK_GITHUB_OWNER="${STACK_GITHUB_OWNER:-Arrumis}"
CLONE_PROTOCOL="${CLONE_PROTOCOL:-https}"

env_get_file() {
  local file_path="$1"
  local key="$2"

  if [[ ! -f "${file_path}" ]]; then
    return 1
  fi

  awk -F '=' -v target="${key}" '
    $0 !~ /^[[:space:]]*#/ && $1 == target {
      sub(/^[^=]*=/, "", $0)
      print $0
      exit
    }
  ' "${file_path}"
}

env_set_file() {
  local file_path="$1"
  local key="$2"
  local value="$3"

  if [[ ! -f "${file_path}" ]]; then
    touch "${file_path}"
  fi

  if grep -qE "^${key}=" "${file_path}"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${file_path}"
  else
    printf '%s=%s\n' "${key}" "${value}" >>"${file_path}"
  fi
}

service_env_prefix() {
  local service_name="$1"
  printf '%s\n' "${service_name}" | tr '[:lower:]-' '[:upper:]_'
}

apply_unified_overrides_for_service() {
  local service_name="$1"
  local service_dir
  local env_file
  local prefix
  local var_name
  local key
  local value

  [[ -f "${UNIFIED_ENV_FILE}" ]] || return 0

  service_dir="$(service_abs_dir "${service_name}")"
  env_file="$(service_env_file "${service_name}")"

  [[ -n "${env_file}" ]] || return 0
  [[ -f "${service_dir}/${env_file}" ]] || return 0

  prefix="$(service_env_prefix "${service_name}")__"

  while IFS= read -r var_name; do
    key="${var_name#${prefix}}"
    value="${!var_name}"
    env_set_file "${service_dir}/${env_file}" "${key}" "${value}"
  done < <(compgen -A variable "${prefix}" || true)
}

load_services() {
  grep -v '^[[:space:]]*#' "${SERVICES_FILE}" | grep -v '^[[:space:]]*$'
}

service_exists() {
  local service_name="$1"
  load_services | awk -F '\t' -v svc="${service_name}" '$1 == svc { found=1 } END { exit(found ? 0 : 1) }'
}

list_default_services() {
  local service

  if [[ -n "${SERVICES:-}" ]]; then
    for service in ${SERVICES}; do
      if service_exists "${service}"; then
        printf '%s\n' "${service}"
      else
        echo "WARN ignoring unknown service in SERVICES: ${service}" >&2
      fi
    done
  else
    load_services | awk -F '\t' '{ print $1 }'
  fi
}

is_excluded_service() {
  local service_name="$1"
  local excluded

  for excluded in ${EXCLUDED_SERVICES:-}; do
    if [[ "${excluded}" == "${service_name}" ]]; then
      return 0
    fi
  done

  return 1
}

filter_excluded_services() {
  local service_name

  while IFS= read -r service_name; do
    [[ -z "${service_name}" ]] && continue
    if is_excluded_service "${service_name}"; then
      continue
    fi
    printf '%s\n' "${service_name}"
  done
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

service_compose_override_file() {
  local service_name="$1"
  resolve_service_row "${service_name}" | awk -F '\t' '{ print $4 }'
}

service_legacy_compose_file() {
  local service_name="$1"
  if [[ -f "${LEGACY_SERVICES_FILE}" ]]; then
    awk -F '\t' -v svc="${service_name}" '$1 == svc { print $2 }' "${LEGACY_SERVICES_FILE}"
    return 0
  fi

  resolve_service_row "${service_name}" | awk -F '\t' '{ print $5 }'
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
  local compose_override

  apply_unified_overrides_for_service "${service_name}"

  service_dir="$(service_abs_dir "${service_name}")"
  env_file="$(service_env_file "${service_name}")"
  compose_override="$(service_compose_override_file "${service_name}")"

  if [[ -n "${env_file}" && -f "${service_dir}/${env_file}" ]]; then
    printf -- "-f\n%s\n" "${service_dir}/compose.yaml"
    if [[ -n "${compose_override}" && -f "${service_dir}/${compose_override}" ]]; then
      printf -- "-f\n%s\n" "${service_dir}/${compose_override}"
    fi
    printf -- "--env-file\n%s\n" "${service_dir}/${env_file}"
  else
    printf -- "-f\n%s\n" "${service_dir}/compose.yaml"
    if [[ -n "${compose_override}" && -f "${service_dir}/${compose_override}" ]]; then
      printf -- "-f\n%s\n" "${service_dir}/${compose_override}"
    fi
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
  else
    list_default_services | filter_excluded_services
  fi
}
