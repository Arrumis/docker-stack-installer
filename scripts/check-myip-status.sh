#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/default/myip-pptp"

if [[ -f "${CONFIG_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
  set +a
fi

echo "== systemctl =="
systemctl is-active myip-pptp 2>/dev/null || true

echo "== ppp0 =="
ip -4 addr show dev ppp0 2>/dev/null || true

echo "== routes =="
ip route | sed -n '1,40p'

echo "== current public ip =="
curl -fsSL --max-time 10 https://api.ipify.org || true
echo

if [[ -n "${MYIP_FIXED_IP:-}" ]]; then
  if ip -4 addr show dev ppp0 2>/dev/null | grep -q "${MYIP_FIXED_IP}"; then
    echo "myIP fixed IP is active on ppp0: ${MYIP_FIXED_IP}"
  else
    echo "myIP fixed IP is not active on ppp0: ${MYIP_FIXED_IP}"
  fi
fi
