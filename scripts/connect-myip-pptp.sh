#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

CONFIG_FILE="/etc/default/myip-pptp"
STATE_DIR="/var/lib/myip-pptp"
STATE_FILE="${STATE_DIR}/state.env"
MYIP_TOOLS_DIR="/etc/myip"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "Missing ${CONFIG_FILE}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${CONFIG_FILE}"
set +a

for required in MYIP_SERVER MYIP_ID MYIP_PASSWORD MYIP_FIXED_IP; do
  if [[ -z "${!required:-}" ]]; then
    echo "Missing ${required} in ${CONFIG_FILE}" >&2
    exit 1
  fi
done

mkdir -p "${STATE_DIR}"

if ip -4 addr show dev ppp0 2>/dev/null | grep -q "${MYIP_FIXED_IP}"; then
  echo "myIP is already connected on ppp0 (${MYIP_FIXED_IP})."
  exit 0
fi

python3 - "${MYIP_SERVER}" <<'PY'
import socket, sys
host = sys.argv[1]
s = socket.socket()
s.settimeout(5)
try:
    s.connect((host, 1723))
except Exception as exc:
    print(f"Cannot reach {host}:1723: {exc}", file=sys.stderr)
    sys.exit(1)
finally:
    s.close()
PY

current_default="$(ip route show default | head -n1)"
if [[ -z "${current_default}" ]]; then
  echo "No default route found before myIP connect." >&2
  exit 1
fi

orig_gateway="$(awk '/default/ {print $3; exit}' <<<"${current_default}")"
orig_dev="$(awk '/default/ {print $5; exit}' <<<"${current_default}")"
orig_src="$(ip -4 addr show dev "${orig_dev}" | awk '/inet / {split($2,a,\"/\"); print a[1]; exit}')"

cat > "${STATE_FILE}" <<EOF
ORIG_DEFAULT_ROUTE=${current_default}
ORIG_GATEWAY=${orig_gateway}
ORIG_DEV=${orig_dev}
ORIG_SRC=${orig_src}
MYIP_SERVER=${MYIP_SERVER}
MYIP_ID=${MYIP_ID}
MYIP_FIXED_IP=${MYIP_FIXED_IP}
EOF

cat > "${MYIP_TOOLS_DIR}/myip.conf" <<EOF
MYIP_SERVER="${MYIP_SERVER}"
ID="${MYIP_ID}"
PASSWORD="${MYIP_PASSWORD}"
IPADDR="${MYIP_FIXED_IP}"
DNS1="${MYIP_DNS1:-203.141.128.35}"
DNS2="${MYIP_DNS2:-203.141.128.33}"
CLIENT_GLOBALIP="AUTO"
EOF

"${MYIP_TOOLS_DIR}/myip-setup" >/dev/null
if [[ -x "${MYIP_TOOLS_DIR}/myip-iptables" ]]; then
  "${MYIP_TOOLS_DIR}/myip-iptables" >/dev/null || true
fi

ip route replace "${MYIP_SERVER}/32" via "${orig_gateway}" dev "${orig_dev}" src "${orig_src}"
pkill -f "pppd call myip_${MYIP_ID}" 2>/dev/null || true

pppd call "myip_${MYIP_ID}" updetach

connected=0
for _ in $(seq 1 30); do
  sleep 1
  if ip -4 addr show dev ppp0 2>/dev/null | grep -q "${MYIP_FIXED_IP}"; then
    connected=1
    break
  fi
done

if [[ "${connected}" -ne 1 ]]; then
  pkill -f "pppd call myip_${MYIP_ID}" 2>/dev/null || true
  ip route replace default via "${orig_gateway}" dev "${orig_dev}" metric 100
  echo "Failed to bring up ppp0 with ${MYIP_FIXED_IP}." >&2
  exit 1
fi

ip route replace default dev ppp0 metric 50

echo "myIP connected: ${MYIP_FIXED_IP} via ppp0"
