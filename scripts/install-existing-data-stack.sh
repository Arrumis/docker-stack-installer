#!/usr/bin/env bash
set -euo pipefail

# 既存 HDD / 既存 Docker データを使って一式を入れる汎用入口です。
# このスクリプト自体はデータ削除・再同期・広範囲 chown を行いません。
# 設定作成、リポジトリ更新、既存インストールスクリプトの呼び出しだけをまとめます。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_USER="${SUDO_USER:-${USER}}"
USER_HOME="$(getent passwd "${INSTALL_USER}" | cut -d: -f6)"
USER_HOME="${USER_HOME:-${HOME}}"
CURRENT_BRANCH="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'main\n')"

STACK_ROOT="${STACK_ROOT:-$(cd "${REPO_ROOT}/.." && pwd)}"
STACK_GITHUB_OWNER="${STACK_GITHUB_OWNER:-Arrumis}"
CLONE_PROTOCOL="${CLONE_PROTOCOL:-https}"
INSTALLER_BRANCH="${INSTALLER_BRANCH:-${CURRENT_BRANCH}}"
DOMAIN="${DOMAIN:-}"
ROOT_HOST="${ROOT_HOST:-}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
PUBLIC_SCHEME="${PUBLIC_SCHEME:-https}"
HOST_DATA_ROOT="${HOST_DATA_ROOT:-${USER_HOME}/docker-data}"
RECORDED_ROOT="${RECORDED_ROOT:-${USER_HOME}/recorded}"
TIMEZONE="${TIMEZONE:-Asia/Tokyo}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-}"
OPENVPN_ADMIN_PASSWORD="${OPENVPN_ADMIN_PASSWORD:-}"
EXCLUDED_SERVICES="${EXCLUDED_SERVICES:-}"
PREPARE_ONLY=0
SKIP_VERIFY=0

usage() {
  cat <<'EOF'
Usage: ./scripts/install-existing-data-stack.sh [options]

既存の Docker データディレクトリを使って stack を入れます。

Options:
  --domain <domain>              公開ドメインです。例: sample.com
  --root-host <host>             WordPress を出すルートホスト名です。省略時は domain と同じです
  --email <email>                Let's Encrypt の通知メールです。省略時は admin@domain です
  --public-scheme <http|https>   公開URLの方式です。既定値は https です
  --host-data-root <path>        既存 Docker データの親ディレクトリです
  --recorded-root <path>         録画ファイルのディレクトリです
  --stack-root <path>            関連リポジトリを置く親ディレクトリです
  --owner <github-owner>         GitHub owner です。既定値は Arrumis です
  --branch <branch>              docker-stack-installer の branch 記録用です
  --exclude-services <list>      インストールしないDockerを空白区切りで指定します
  --prepare-only                 設定作成とリポジトリ更新だけ行い、Docker 起動はしません
  --skip-verify                  起動後の verify-stack.sh を飛ばします
  --basic-auth-password <pw>     Traefik 保護画面の Basic 認証パスワード
  --openvpn-admin-password <pw>  OpenVPN admin パスワードを明示変更します
  -h, --help                     このヘルプを表示します

注意:
  - データ削除や rsync はしません。
  - OpenVPN admin パスワードは、指定した場合だけ変更します。
  - 録画系は host 準備と Mirakurun conf の最小権限補正を既存 install script 側で行います。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --root-host)
      ROOT_HOST="$2"
      shift 2
      ;;
    --email)
      LETSENCRYPT_EMAIL="$2"
      shift 2
      ;;
    --public-scheme)
      PUBLIC_SCHEME="$2"
      shift 2
      ;;
    --host-data-root)
      HOST_DATA_ROOT="$2"
      shift 2
      ;;
    --recorded-root)
      RECORDED_ROOT="$2"
      shift 2
      ;;
    --stack-root)
      STACK_ROOT="$2"
      shift 2
      ;;
    --owner)
      STACK_GITHUB_OWNER="$2"
      shift 2
      ;;
    --branch)
      INSTALLER_BRANCH="$2"
      shift 2
      ;;
    --exclude-services)
      EXCLUDED_SERVICES="$2"
      shift 2
      ;;
    --prepare-only)
      PREPARE_ONLY=1
      shift
      ;;
    --skip-verify)
      SKIP_VERIFY=1
      shift
      ;;
    --basic-auth-password)
      BASIC_AUTH_PASSWORD="$2"
      shift 2
      ;;
    --openvpn-admin-password)
      OPENVPN_ADMIN_PASSWORD="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "不明なオプションです: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${DOMAIN}" ]]; then
  echo "--domain が必要です。" >&2
  usage >&2
  exit 1
fi

ROOT_HOST="${ROOT_HOST:-${DOMAIN}}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@${DOMAIN}}"

backup_if_exists() {
  local file_path="$1"
  if [[ -f "${file_path}" ]]; then
    cp -a "${file_path}" "${file_path}.bak.$(date '+%Y%m%d-%H%M%S')"
  fi
}

require_dir() {
  local label="$1"
  local dir_path="$2"
  if [[ ! -d "${dir_path}" ]]; then
    echo "NG ${label}: ${dir_path} がありません。" >&2
    echo "マウント先やパスを確認してから再実行してください。" >&2
    exit 1
  fi
}

write_stack_env() {
  local path="${REPO_ROOT}/stack.env.local"
  backup_if_exists "${path}"
  cat >"${path}" <<EOF
STACK_ROOT=${STACK_ROOT}
STACK_GITHUB_OWNER=${STACK_GITHUB_OWNER}
CLONE_PROTOCOL=${CLONE_PROTOCOL}
INSTALLER_BRANCH=${INSTALLER_BRANCH}
SERVICES="infra-reverse-proxy infra-fail2ban infra-munin app-tategaki app-wordpress app-ttrss app-syncthing app-openvpn app-mirakurun-epgstation"
EXCLUDED_SERVICES="${EXCLUDED_SERVICES}"
AUTO_ENABLE_HTTPS=1
EOF
  echo "WRITE ${path}"
}

write_stack_service_env() {
  local path="${REPO_ROOT}/stack.service.env.local"
  backup_if_exists "${path}"
  cat >"${path}" <<EOF
GLOBAL__DOMAIN=${DOMAIN}
GLOBAL__ROOT_HOST=${ROOT_HOST}
GLOBAL__PUBLIC_SCHEME=${PUBLIC_SCHEME}
GLOBAL__LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
GLOBAL__TZ=${TIMEZONE}
GLOBAL__PUID=${PUID}
GLOBAL__PGID=${PGID}
GLOBAL__BASIC_AUTH_USER=${BASIC_AUTH_USER}
GLOBAL__HOST_DATA_ROOT=${HOST_DATA_ROOT}
GLOBAL__RECORDED_ROOT=${RECORDED_ROOT}
GLOBAL__PROXY_NETWORK_NAME=proxy-network
GLOBAL__PROXY_LOG_DIR=${STACK_ROOT%/}/infra-reverse-proxy/data/log
EOF
  if [[ -n "${BASIC_AUTH_PASSWORD}" ]]; then
    printf 'GLOBAL__BASIC_AUTH_PASSWORD=%s\n' "${BASIC_AUTH_PASSWORD}" >>"${path}"
  fi
  echo "WRITE ${path}"
}

configure_default_envs() {
  local cmd=(
    "${REPO_ROOT}/scripts/configure-default-envs.sh"
    --domain "${DOMAIN}"
    --root-host "${ROOT_HOST}"
    --email "${LETSENCRYPT_EMAIL}"
    --public-scheme "${PUBLIC_SCHEME}"
    --basic-auth-user "${BASIC_AUTH_USER}"
    --excluded-services "${EXCLUDED_SERVICES}"
  )

  if [[ -n "${BASIC_AUTH_PASSWORD}" ]]; then
    cmd+=(--basic-auth-password "${BASIC_AUTH_PASSWORD}")
  fi
  if [[ -n "${OPENVPN_ADMIN_PASSWORD}" ]]; then
    cmd+=(--openvpn-admin-password "${OPENVPN_ADMIN_PASSWORD}")
  fi

  "${cmd[@]}"
}

main() {
  cd "${REPO_ROOT}"

  echo "== existing data stack install =="
  echo "作業リポジトリ: ${REPO_ROOT}"
  echo "STACK_ROOT: ${STACK_ROOT}"
  echo "HOST_DATA_ROOT: ${HOST_DATA_ROOT}"
  echo "RECORDED_ROOT: ${RECORDED_ROOT}"
  echo "開始日時: $(date '+%Y-%m-%d %H:%M:%S %z')"

  require_dir "既存 Docker データ" "${HOST_DATA_ROOT}"
  require_dir "録画ディレクトリ" "${RECORDED_ROOT}"

  write_stack_env
  write_stack_service_env

  "${REPO_ROOT}/scripts/bootstrap-repos.sh"
  "${REPO_ROOT}/scripts/init-env-files.sh"
  configure_default_envs

  if [[ "${PREPARE_ONLY}" -eq 1 ]]; then
    echo "prepare-only のため、Docker 起動は行いません。"
    echo "env を確認してから実行する場合:"
    echo "  cd ${REPO_ROOT}"
    echo "  ./scripts/run-full-stack.sh --skip-bootstrap --skip-init-env"
    return 0
  fi

  if [[ "${SKIP_VERIFY}" -eq 1 ]]; then
    "${REPO_ROOT}/scripts/run-full-stack.sh" --skip-bootstrap --skip-init-env --skip-verify
  else
    "${REPO_ROOT}/scripts/run-full-stack.sh" --skip-bootstrap --skip-init-env
  fi

  echo "終了日時: $(date '+%Y-%m-%d %H:%M:%S %z')"
}

main "$@"
