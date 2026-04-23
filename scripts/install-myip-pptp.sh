#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/install-myip-pptp.sh --server <vpn-server> --id <miXXXXXX> --password <password> --fixed-ip <x.x.x.x>

Installs the official Interlink myIP PPTP tools and a safer systemd wrapper.

Options:
  --server <host-or-ip>   VPN server issued by Interlink
  --id <login-id>         myIP login ID, e.g. mi123456
  --password <password>   myIP password
  --fixed-ip <ip>         Assigned fixed public IP
  --dns1 <ip>             Optional. Default: 203.141.128.35
  --dns2 <ip>             Optional. Default: 203.141.128.33
EOF
}

MYIP_SERVER=""
MYIP_ID=""
MYIP_PASSWORD=""
MYIP_FIXED_IP=""
MYIP_DNS1="203.141.128.35"
MYIP_DNS2="203.141.128.33"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server)
      MYIP_SERVER="$2"
      shift 2
      ;;
    --id)
      MYIP_ID="$2"
      shift 2
      ;;
    --password)
      MYIP_PASSWORD="$2"
      shift 2
      ;;
    --fixed-ip)
      MYIP_FIXED_IP="$2"
      shift 2
      ;;
    --dns1)
      MYIP_DNS1="$2"
      shift 2
      ;;
    --dns2)
      MYIP_DNS2="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${MYIP_SERVER}" || -z "${MYIP_ID}" || -z "${MYIP_PASSWORD}" || -z "${MYIP_FIXED_IP}" ]]; then
  usage >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo apt-get update
sudo apt-get install -y curl ppp pptp-linux

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl -fsSL https://www.interlink.or.jp/support/vpn/myip/myiptools/myiptools.tar.gz -o "${tmpdir}/myiptools.tar.gz"
sudo mkdir -p /etc/myip
sudo tar xvzf "${tmpdir}/myiptools.tar.gz" -C /etc >/dev/null

sudo tee /etc/default/myip-pptp >/dev/null <<EOF
MYIP_SERVER="${MYIP_SERVER}"
MYIP_ID="${MYIP_ID}"
MYIP_PASSWORD="${MYIP_PASSWORD}"
MYIP_FIXED_IP="${MYIP_FIXED_IP}"
MYIP_DNS1="${MYIP_DNS1}"
MYIP_DNS2="${MYIP_DNS2}"
EOF

sudo cp "${SCRIPT_DIR}/connect-myip-pptp.sh" /usr/local/sbin/connect-myip-pptp
sudo cp "${SCRIPT_DIR}/disconnect-myip-pptp.sh" /usr/local/sbin/disconnect-myip-pptp
sudo chmod 700 /usr/local/sbin/connect-myip-pptp /usr/local/sbin/disconnect-myip-pptp

sudo tee /etc/systemd/system/myip-pptp.service >/dev/null <<'EOF'
[Unit]
Description=Interlink myIP PPTP connection
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/connect-myip-pptp
ExecStop=/usr/local/sbin/disconnect-myip-pptp

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

cat <<EOF
Installed myIP PPTP helper.

Config file:
  /etc/default/myip-pptp

Useful commands:
  sudo systemctl start myip-pptp
  sudo systemctl status myip-pptp
  ./scripts/check-myip-status.sh
EOF
