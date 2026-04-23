#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

status=0

check_cmd() {
  local cmd="$1"
  if command -v "${cmd}" >/dev/null 2>&1; then
    echo "OK command: ${cmd}"
  else
    echo "MISSING command: ${cmd}"
    status=1
  fi
}

echo "== host =="
echo "user: $(id -un)"
echo "uid:gid = $(id -u):$(id -g)"
echo "stack root: ${STACK_ROOT}"
echo

echo "== commands =="
check_cmd git
check_cmd docker
if docker compose version >/dev/null 2>&1; then
  echo "OK command: docker compose"
else
  echo "MISSING command: docker compose"
  status=1
fi
echo

echo "== docker access =="
if docker info >/dev/null 2>&1; then
  echo "OK docker daemon access"
else
  echo "NG docker daemon access"
  status=1
fi
echo

echo "== repos =="
while IFS= read -r service_name; do
  service_dir="$(service_abs_dir "${service_name}")"
  if [[ -d "${service_dir}/.git" ]]; then
    echo "OK repo: ${service_name}"
  else
    echo "MISS repo: ${service_name} -> ${service_dir}"
    status=1
  fi
done < <(list_target_services "$@")
echo

echo "== network =="
if docker network inspect proxy-network >/dev/null 2>&1; then
  echo "OK network: proxy-network"
else
  echo "WARN network missing: proxy-network"
fi

exit "${status}"

