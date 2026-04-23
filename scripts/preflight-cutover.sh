#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

extract_published_ports() {
  local service_name="$1"
  run_new_compose "${service_name}" config 2>/dev/null \
    | sed -n 's/^[[:space:]]*published: "\(.*\)"/\1/p'
}

docker_ps_lines() {
  docker ps --format '{{.Names}}\t{{.Ports}}'
}

while IFS= read -r service_name; do
  echo "== ${service_name} =="

  service_dir="$(service_abs_dir "${service_name}")"
  legacy_compose="$(service_legacy_compose_file "${service_name}")"

  echo "new repo: ${service_dir}"
  echo "legacy compose: ${legacy_compose:-<none>}"

  if [[ -n "${legacy_compose}" && -f "${legacy_compose}" ]]; then
    echo "legacy compose: OK"
  else
    echo "legacy compose: missing"
  fi

  ports="$(extract_published_ports "${service_name}" || true)"
  if [[ -z "${ports}" ]]; then
    echo "published ports: none"
    echo
    continue
  fi

  echo "published ports:"
  printf '%s\n' "${ports}" | sed 's/^/  - /'

  echo "current holders:"
  while IFS= read -r port; do
    match="$(docker_ps_lines | grep -E "[:>]${port}->|published: \"${port}\"" || true)"
    if [[ -n "${match}" ]]; then
      printf '%s\n' "${match}" | sed "s/^/  - /"
    else
      echo "  - port ${port}: free"
    fi
  done < <(printf '%s\n' "${ports}")

  echo
done < <(list_target_services "$@")

