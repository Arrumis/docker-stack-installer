#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

CONFIG_FILE="/etc/default/myip-pptp"
STATE_FILE="/var/lib/myip-pptp/state.env"

if [[ -f "${CONFIG_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
  set +a
fi

if [[ -f "${STATE_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
  set +a
fi

if [[ -n "${MYIP_ID:-}" ]]; then
  pkill -f "pppd call myip_${MYIP_ID}" 2>/dev/null || true
fi

sleep 2

if [[ -n "${ORIG_GATEWAY:-}" && -n "${ORIG_DEV:-}" ]]; then
  ip route replace default via "${ORIG_GATEWAY}" dev "${ORIG_DEV}" metric 100
fi

if [[ -n "${MYIP_SERVER:-}" ]]; then
  ip route del "${MYIP_SERVER}/32" 2>/dev/null || true
fi

echo "myIP disconnected."
