#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

RUN_BOOTSTRAP=1
RUN_INIT_ENV=1
RUN_DOCTOR=1
RUN_LAYOUT_CHECK=1
BUILD_IMAGES=1

usage() {
  cat <<'EOF'
Usage: ./scripts/install-full-stack.sh [options] [service ...]

Options:
  --skip-bootstrap   Do not clone/pull sibling repos
  --skip-init-env    Do not create missing .env.local files
  --skip-doctor      Skip doctor.sh
  --skip-check       Skip check-layout.sh
  --no-build         Run docker compose up -d without --build
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-bootstrap)
      RUN_BOOTSTRAP=0
      shift
      ;;
    --skip-init-env)
      RUN_INIT_ENV=0
      shift
      ;;
    --skip-doctor)
      RUN_DOCTOR=0
      shift
      ;;
    --skip-check)
      RUN_LAYOUT_CHECK=0
      shift
      ;;
    --no-build)
      BUILD_IMAGES=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

mapfile -t target_services < <(list_target_services "$@")

run_service_script_if_present() {
  local service_name="$1"
  local script_rel_path="$2"
  local service_dir

  service_dir="$(service_abs_dir "${service_name}")"
  if [[ -x "${service_dir}/${script_rel_path}" ]]; then
    echo "== init ${service_name}: ${script_rel_path} =="
    (
      cd "${service_dir}"
      "./${script_rel_path}"
    )
  fi
}

run_sudo_if_needed() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return 0
  fi

  sudo "$@"
}

repair_mirakurun_config_permissions() {
  local service_name="app-mirakurun-epgstation"
  local service_dir
  local env_file
  local config_dir
  local current_uid
  local current_gid
  local entries=()
  local path
  local needs_repair=0
  local did_repair=0

  service_dir="$(service_abs_dir "${service_name}")"
  env_file="$(service_env_file "${service_name}")"

  [[ -n "${env_file}" && -f "${service_dir}/${env_file}" ]] || return 0

  apply_unified_overrides_for_service "${service_name}"

  config_dir="$(env_get_file "${service_dir}/${env_file}" "MIRAKURUN_CONFIG_DIR" 2>/dev/null || true)"
  config_dir="${config_dir:-}"
  [[ -n "${config_dir}" && -d "${config_dir}" ]] || return 0

  # 旧HDDから引き継いだ Mirakurun 設定が root:root 0600 のままだと、
  # init-data-dirs.sh が server.yml を grep/更新できずに止まる。
  # 録画データや他サービスには触れず、Mirakurun の conf 直下だけを補正する。
  current_uid="$(id -u)"
  current_gid="$(id -g)"

  if [[ ! -r "${config_dir}" || ! -w "${config_dir}" || ! -x "${config_dir}" ]]; then
    echo "== repair app-mirakurun-epgstation: Mirakurun 設定権限 =="
    echo "Mirakurun 設定ディレクトリを init-data-dirs.sh が読めるように補正します: ${config_dir}"
    run_sudo_if_needed chown "${current_uid}:${current_gid}" "${config_dir}"
    run_sudo_if_needed chmod u+rwx "${config_dir}"
    did_repair=1
  fi

  while IFS= read -r -d '' path; do
    entries+=("${path}")
    if [[ ! -r "${path}" || ! -w "${path}" ]]; then
      needs_repair=1
    fi
  done < <(find "${config_dir}" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

  [[ "${needs_repair}" -eq 1 ]] || return 0

  if [[ "${did_repair}" -eq 0 ]]; then
    echo "== repair app-mirakurun-epgstation: Mirakurun 設定権限 =="
    echo "Mirakurun 設定ファイルを init-data-dirs.sh が読めるように補正します: ${config_dir}"
  fi

  if [[ "${#entries[@]}" -gt 0 ]]; then
    run_sudo_if_needed chown "${current_uid}:${current_gid}" "${entries[@]}"
    run_sudo_if_needed chmod u+rw "${entries[@]}"
  fi
}

setup_munin_host_node() {
  local service_name="infra-munin"
  local service_dir
  local env_file
  local docker_cidr

  service_dir="$(service_abs_dir "${service_name}")"
  env_file="$(service_env_file "${service_name}")"

  if [[ ! -x "${service_dir}/scripts/setup-host-munin-node.sh" ]]; then
    return 0
  fi

  docker_cidr="$(
    env_get_file "${service_dir}/${env_file}" "MUNIN_ALLOWED_CIDR" 2>/dev/null || true
  )"
  docker_cidr="${docker_cidr:-172.16.0.0/12}"

  echo "== init infra-munin: scripts/setup-host-munin-node.sh =="
  (
    cd "${service_dir}"
    ./scripts/setup-host-munin-node.sh 127.0.0.1 "${docker_cidr}"
  )
}

preinstall_service() {
  local service_name="$1"
  case "${service_name}" in
    infra-reverse-proxy)
      run_service_script_if_present "${service_name}" "scripts/init-layout.sh"
      run_service_script_if_present "${service_name}" "scripts/create-network.sh"
      ;;
    infra-fail2ban)
      run_service_script_if_present "${service_name}" "scripts/init-runtime.sh"
      ;;
    infra-munin)
      run_service_script_if_present "${service_name}" "scripts/init-layout.sh"
      setup_munin_host_node
      ;;
    app-wordpress|app-ttrss|app-syncthing|app-openvpn|app-tategaki|app-mirakurun-epgstation)
      if [[ "${service_name}" == "app-mirakurun-epgstation" ]]; then
        run_service_script_if_present "${service_name}" "scripts/prepare-host.sh"
        repair_mirakurun_config_permissions
      fi
      run_service_script_if_present "${service_name}" "scripts/init-data-dirs.sh"
      ;;
  esac
}

postinstall_service() {
  local service_name="$1"
  local service_dir
  local env_file
  local openvpn_admin_password

  case "${service_name}" in
    infra-reverse-proxy)
      if docker compose -f "$(service_abs_dir "${service_name}")/compose.yaml" --env-file "$(service_abs_dir "${service_name}")/$(service_env_file "${service_name}")" exec -T nginx-proxy nginx -t >/dev/null 2>&1; then
        docker compose -f "$(service_abs_dir "${service_name}")/compose.yaml" --env-file "$(service_abs_dir "${service_name}")/$(service_env_file "${service_name}")" exec -T nginx-proxy nginx -s reload
      fi
      ;;
    app-openvpn)
      service_dir="$(service_abs_dir "${service_name}")"
      env_file="$(service_env_file "${service_name}")"
      openvpn_admin_password="$(env_get_file "${service_dir}/${env_file}" "OPENVPN_ADMIN_PASSWORD" 2>/dev/null || true)"
      case "${openvpn_admin_password}" in
        ""|change-me)
          echo "SKIP app-openvpn: OPENVPN_ADMIN_PASSWORD が未指定のため admin パスワード変更は行いません"
          ;;
        *)
          run_service_script_if_present "${service_name}" "scripts/set-admin-password.sh"
          ;;
      esac
      ;;
    app-ttrss)
      run_service_script_if_present "${service_name}" "scripts/capture-admin-password.sh"
      ;;
  esac
}

if [[ "${RUN_BOOTSTRAP}" -eq 1 ]]; then
  "${SCRIPT_DIR}/bootstrap-repos.sh"
fi

if [[ "${RUN_INIT_ENV}" -eq 1 ]]; then
  "${SCRIPT_DIR}/init-env-files.sh"
fi

if [[ "${RUN_DOCTOR}" -eq 1 ]]; then
  "${SCRIPT_DIR}/doctor.sh"
fi

if [[ "${RUN_LAYOUT_CHECK}" -eq 1 ]]; then
  "${SCRIPT_DIR}/check-layout.sh" "${target_services[@]}"
fi

for service_name in "${target_services[@]}"; do
  service_dir="$(service_abs_dir "${service_name}")"
  if [[ ! -d "${service_dir}" ]]; then
    echo "SKIP ${service_name}: repo dir not found at ${service_dir}"
    continue
  fi

  preinstall_service "${service_name}"

  echo "== starting ${service_name} =="
  if [[ "${BUILD_IMAGES}" -eq 1 ]]; then
    run_new_compose "${service_name}" up -d --build
  else
    run_new_compose "${service_name}" up -d
  fi

  postinstall_service "${service_name}"
done

"${SCRIPT_DIR}/enable-https-if-possible.sh" "${target_services[@]}"

echo "Full stack install finished for: ${target_services[*]}"
