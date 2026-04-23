#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

DRY_RUN=true
if [[ "${1:-}" == "--apply" ]]; then
  DRY_RUN=false
  shift
fi

if [[ "$#" -lt 1 ]]; then
  echo "usage: $0 [--apply] <service> [service...]"
  exit 1
fi

for service_name in "$@"; do
  echo "== cutover ${service_name} =="

  legacy_compose="$(service_legacy_compose_file "${service_name}")"
  if [[ -z "${legacy_compose}" || ! -f "${legacy_compose}" ]]; then
    echo "SKIP ${service_name}: legacy compose not found"
    continue
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "DRY RUN:"
    echo "  docker compose -f ${legacy_compose} down"
    echo "  $(printf 'docker compose '; service_compose_args "${service_name}" | tr '\n' ' ') up -d"
    continue
  fi

  run_legacy_compose "${service_name}" down
  run_new_compose "${service_name}" up -d
done

