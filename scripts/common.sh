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
STACK_GITHUB_OWNER="${STACK_GITHUB_OWNER:-your-github-user}"
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

service_default_data_subdir() {
  local service_name="$1"
  case "${service_name}" in
    app-wordpress) printf 'wordpress\n' ;;
    app-ttrss) printf 'ttrss\n' ;;
    app-tategaki) printf 'tategaki\n' ;;
    app-syncthing) printf 'syncthing\n' ;;
    app-openvpn) printf 'openvpn\n' ;;
    app-mirakurun-epgstation) printf 'mirakurun-epgstation\n' ;;
    infra-reverse-proxy) printf 'reverse-proxy\n' ;;
    infra-fail2ban) printf 'fail2ban\n' ;;
    infra-munin) printf 'munin\n' ;;
    *) printf '%s\n' "${service_name}" ;;
  esac
}

apply_unified_global_layout_for_service() {
  local service_name="$1"
  local service_dir
  local env_file
  local domain
  local root_host
  local public_scheme
  local letsencrypt_email
  local timezone
  local puid
  local pgid
  local basic_auth_user
  local basic_auth_password

  [[ -f "${UNIFIED_ENV_FILE}" ]] || return 0

  service_dir="$(service_abs_dir "${service_name}")"
  env_file="$(service_env_file "${service_name}")"
  [[ -n "${env_file}" ]] || return 0
  [[ -f "${service_dir}/${env_file}" ]] || return 0

  domain="${GLOBAL__DOMAIN:-}"
  root_host="${GLOBAL__ROOT_HOST:-${domain}}"
  public_scheme="${GLOBAL__PUBLIC_SCHEME:-https}"
  letsencrypt_email="${GLOBAL__LETSENCRYPT_EMAIL:-}"
  timezone="${GLOBAL__TZ:-}"
  puid="${GLOBAL__PUID:-}"
  pgid="${GLOBAL__PGID:-}"
  basic_auth_user="${GLOBAL__BASIC_AUTH_USER:-}"
  basic_auth_password="${GLOBAL__BASIC_AUTH_PASSWORD:-}"

  if [[ -z "${letsencrypt_email}" && -n "${domain}" ]]; then
    letsencrypt_email="admin@${domain}"
  fi

  case "${service_name}" in
    infra-reverse-proxy)
      if [[ -n "${domain}" ]]; then
        env_set_file "${service_dir}/${env_file}" "DOMAIN" "${domain}"
        env_set_file "${service_dir}/${env_file}" "ROOT_HOST" "${root_host}"
        env_set_file "${service_dir}/${env_file}" "TTRSS_HOST" "ttrss.${domain}"
        env_set_file "${service_dir}/${env_file}" "MUNIN_HOST" "munin.${domain}"
        env_set_file "${service_dir}/${env_file}" "TATEGAKI_HOST" "tategaki.${domain}"
        env_set_file "${service_dir}/${env_file}" "SYNCTHING_HOST" "syncthing.${domain}"
        env_set_file "${service_dir}/${env_file}" "OPENVPN_HOST" "openvpn.${domain}"
        env_set_file "${service_dir}/${env_file}" "TRAEFIK_HOST" "traefik.${domain}"
        env_set_file "${service_dir}/${env_file}" "MIRAKURUN_HOST" "mirakurun.${domain}"
        env_set_file "${service_dir}/${env_file}" "EPGREC_HOST" "epgrec.${domain}"
        env_set_file "${service_dir}/${env_file}" "EPGSTATION_HOST" "epgstation.${domain}"
      fi
      if [[ -n "${letsencrypt_email}" ]]; then
        env_set_file "${service_dir}/${env_file}" "LETSENCRYPT_EMAIL" "${letsencrypt_email}"
      fi
      if [[ -n "${basic_auth_user}" ]]; then
        env_set_file "${service_dir}/${env_file}" "BASIC_AUTH_USER" "${basic_auth_user}"
      fi
      if [[ -n "${basic_auth_password}" ]]; then
        env_set_file "${service_dir}/${env_file}" "BASIC_AUTH_PASSWORD" "${basic_auth_password}"
      fi
      if [[ -n "${timezone}" ]]; then
        env_set_file "${service_dir}/${env_file}" "TZ" "${timezone}"
      fi
      ;;
    app-ttrss)
      if [[ -n "${domain}" ]]; then
        env_set_file "${service_dir}/${env_file}" "TTRSS_SELF_URL_PATH" "${public_scheme}://ttrss.${domain}/tt-rss/"
      fi
      if [[ -n "${timezone}" ]]; then
        env_set_file "${service_dir}/${env_file}" "TZ" "${timezone}"
      fi
      ;;
    app-syncthing|app-openvpn)
      if [[ -n "${puid}" ]]; then
        env_set_file "${service_dir}/${env_file}" "PUID" "${puid}"
      fi
      if [[ -n "${pgid}" ]]; then
        env_set_file "${service_dir}/${env_file}" "PGID" "${pgid}"
      fi
      if [[ -n "${timezone}" ]]; then
        env_set_file "${service_dir}/${env_file}" "TZ" "${timezone}"
      fi
      ;;
    app-mirakurun-epgstation)
      if [[ -n "${puid}" ]]; then
        env_set_file "${service_dir}/${env_file}" "EPGSTATION_UID" "${puid}"
      fi
      if [[ -n "${pgid}" ]]; then
        env_set_file "${service_dir}/${env_file}" "EPGSTATION_GID" "${pgid}"
      fi
      if [[ -n "${timezone}" ]]; then
        env_set_file "${service_dir}/${env_file}" "TZ" "${timezone}"
      fi
      ;;
    infra-fail2ban|infra-munin|app-tategaki|app-wordpress)
      if [[ -n "${timezone}" ]]; then
        env_set_file "${service_dir}/${env_file}" "TZ" "${timezone}"
      fi
      ;;
  esac
}

apply_unified_data_layout_for_service() {
  local service_name="$1"
  local service_dir
  local env_file
  local prefix
  local data_root
  local recorded_root
  local data_subdir_var
  local recorded_subdir_var
  local data_subdir
  local recorded_subdir
  local service_root

  [[ -f "${UNIFIED_ENV_FILE}" ]] || return 0

  data_root="${GLOBAL__HOST_DATA_ROOT:-}"
  recorded_root="${GLOBAL__RECORDED_ROOT:-}"
  [[ -n "${data_root}" || -n "${recorded_root}" ]] || return 0

  service_dir="$(service_abs_dir "${service_name}")"
  env_file="$(service_env_file "${service_name}")"
  [[ -n "${env_file}" ]] || return 0
  [[ -f "${service_dir}/${env_file}" ]] || return 0

  prefix="$(service_env_prefix "${service_name}")__"
  data_subdir_var="${prefix}DATA_SUBDIR"
  recorded_subdir_var="${prefix}RECORDED_SUBDIR"
  data_subdir="${!data_subdir_var:-$(service_default_data_subdir "${service_name}")}"
  recorded_subdir="${!recorded_subdir_var:-${data_subdir}}"

  if [[ -n "${data_root}" ]]; then
    service_root="${data_root%/}/${data_subdir}"
    case "${service_name}" in
      app-wordpress)
        env_set_file "${service_dir}/${env_file}" "HOST_DATA_DIR" "${service_root}"
        env_set_file "${service_dir}/${env_file}" "WORDPRESS_HTML_DIR" "${service_root}/html"
        env_set_file "${service_dir}/${env_file}" "WORDPRESS_DB_DIR" "${service_root}/db"
        ;;
      app-ttrss)
        env_set_file "${service_dir}/${env_file}" "HOST_DATA_DIR" "${service_root}"
        env_set_file "${service_dir}/${env_file}" "TTRSS_DB_DIR" "${service_root}/db"
        env_set_file "${service_dir}/${env_file}" "TTRSS_APP_DIR" "${service_root}/app"
        env_set_file "${service_dir}/${env_file}" "TTRSS_CONFIG_DIR" "${service_root}/config.d"
        ;;
      app-tategaki)
        env_set_file "${service_dir}/${env_file}" "HOST_DATA_DIR" "${service_root}"
        env_set_file "${service_dir}/${env_file}" "TATEGAKI_DATA_DIR" "${service_root}"
        ;;
      app-syncthing)
        env_set_file "${service_dir}/${env_file}" "HOST_DATA_DIR" "${service_root}"
        env_set_file "${service_dir}/${env_file}" "SYNCTHING_CONFIG_DIR" "${service_root}/config"
        env_set_file "${service_dir}/${env_file}" "SYNCTHING_STORAGE_DIR" "${service_root}/storage"
        ;;
      app-openvpn)
        env_set_file "${service_dir}/${env_file}" "HOST_DATA_DIR" "${service_root}"
        env_set_file "${service_dir}/${env_file}" "OPENVPN_CONFIG_DIR" "${service_root}/config"
        ;;
      app-mirakurun-epgstation)
        env_set_file "${service_dir}/${env_file}" "HOST_DATA_DIR" "${service_root}"
        env_set_file "${service_dir}/${env_file}" "MIRAKURUN_CONFIG_DIR" "${service_root}/mirakurun/conf"
        env_set_file "${service_dir}/${env_file}" "MIRAKURUN_DATA_DIR" "${service_root}/mirakurun/data"
        env_set_file "${service_dir}/${env_file}" "EPG_DB_DIR" "${service_root}/mariadb"
        env_set_file "${service_dir}/${env_file}" "EPGSTATION_CONFIG_DIR" "${service_root}/epgstation/config"
        env_set_file "${service_dir}/${env_file}" "EPGSTATION_DATA_DIR" "${service_root}/epgstation/data"
        env_set_file "${service_dir}/${env_file}" "EPGSTATION_THUMBNAIL_DIR" "${service_root}/epgstation/thumbnail"
        env_set_file "${service_dir}/${env_file}" "EPGSTATION_LOGS_DIR" "${service_root}/epgstation/logs"
        ;;
    esac
  fi

  if [[ -n "${recorded_root}" && "${service_name}" == "app-mirakurun-epgstation" ]]; then
    env_set_file "${service_dir}/${env_file}" "RECORDED_DIR" "${recorded_root%/}/${recorded_subdir}"
  fi
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

  apply_unified_global_layout_for_service "${service_name}"
  apply_unified_data_layout_for_service "${service_name}"

  prefix="$(service_env_prefix "${service_name}")__"

  while IFS= read -r var_name; do
    key="${var_name#${prefix}}"
    case "${key}" in
      DATA_SUBDIR|RECORDED_SUBDIR)
        continue
        ;;
    esac
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
