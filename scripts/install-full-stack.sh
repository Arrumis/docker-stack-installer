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
      ;;
    app-wordpress|app-ttrss|app-syncthing|app-openvpn|app-tategaki|app-mirakurun-epgstation)
      if [[ "${service_name}" == "app-mirakurun-epgstation" ]]; then
        run_service_script_if_present "${service_name}" "scripts/prepare-host.sh"
      fi
      run_service_script_if_present "${service_name}" "scripts/init-data-dirs.sh"
      ;;
  esac
}

postinstall_service() {
  local service_name="$1"
  case "${service_name}" in
    infra-reverse-proxy)
      if docker compose -f "$(service_abs_dir "${service_name}")/compose.yaml" --env-file "$(service_abs_dir "${service_name}")/$(service_env_file "${service_name}")" exec -T nginx-proxy nginx -t >/dev/null 2>&1; then
        docker compose -f "$(service_abs_dir "${service_name}")/compose.yaml" --env-file "$(service_abs_dir "${service_name}")/$(service_env_file "${service_name}")" exec -T nginx-proxy nginx -s reload
      fi
      ;;
    app-openvpn)
      run_service_script_if_present "${service_name}" "scripts/set-admin-password.sh"
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
