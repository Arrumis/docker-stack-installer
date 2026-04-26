#!/usr/bin/env bash
set -euo pipefail

STACK_ROOT="${STACK_ROOT:-${HOME}/docker-stack}"
STACK_GITHUB_OWNER="${STACK_GITHUB_OWNER:-your-github-user}"
CLONE_PROTOCOL="${CLONE_PROTOCOL:-https}"
DOMAIN="${DOMAIN:-}"
ROOT_HOST="${ROOT_HOST:-}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
PUBLIC_SCHEME="${PUBLIC_SCHEME:-http}"
EXCLUDED_SERVICES="${EXCLUDED_SERVICES:-}"
OPENVPN_ADMIN_PASSWORD="${OPENVPN_ADMIN_PASSWORD:-}"
BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-}"
HOST_DATA_ROOT="${HOST_DATA_ROOT:-}"
RECORDED_ROOT="${RECORDED_ROOT:-}"
AUTO_ENABLE_HTTPS="${AUTO_ENABLE_HTTPS:-1}"
INSTALLER_DIR="${INSTALLER_DIR:-${STACK_ROOT}/docker-stack-installer}"
SKIP_INSTALL="${SKIP_INSTALL:-0}"
SKIP_VERIFY="${SKIP_VERIFY:-0}"
PREPARE_ONLY="${PREPARE_ONLY:-0}"
GUIDED="${GUIDED:-0}"

usage() {
  cat <<'EOF'
使い方:
  bootstrap-clean-ubuntu.sh [options]

主なオプション:
  --guided                       対話式で必要値を聞き、そのままインストールまで進めます
  --prepare-only                 必要パッケージ、repo取得、env作成まで行って止めます
  --domain <domain>              公開ドメインです。例: sample.com
  --owner <github-owner>         GitHub のユーザー名または owner 名です

詳細オプション:
  --root-host <host>             WordPress を出すルートホスト名です。省略時は domain と同じです
  --email <email>                Let's Encrypt の通知メールです
  --public-scheme <http|https>   公開URLの方式です
  --stack-root <path>            repo を clone する親ディレクトリです
  --protocol <https|ssh>         sibling repo の clone 方式です
  --exclude-services <list>      インストールしないDockerを空白区切りで指定します
  --openvpn-admin-password <pw>  OpenVPN 管理者パスワードです
  --basic-auth-user <user>       保護された管理画面の Basic 認証ユーザー名です
  --basic-auth-password <pw>     保護された管理画面の Basic 認証パスワードです
  --host-data-root <path>        永続データの親ディレクトリです
  --recorded-root <path>         録画ファイルの親ディレクトリです
  --skip-https                   HTTPS 自動昇格を行いません
  --skip-install                 repo/env 準備後にインストールせず止めます
  --skip-verify                  最後の verify-stack.sh を省略します
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
    --stack-root)
      STACK_ROOT="$2"
      INSTALLER_DIR="${STACK_ROOT}/docker-stack-installer"
      shift 2
      ;;
    --owner)
      STACK_GITHUB_OWNER="$2"
      shift 2
      ;;
    --protocol)
      CLONE_PROTOCOL="$2"
      shift 2
      ;;
    --exclude-services)
      EXCLUDED_SERVICES="$2"
      shift 2
      ;;
    --openvpn-admin-password)
      OPENVPN_ADMIN_PASSWORD="$2"
      shift 2
      ;;
    --basic-auth-user)
      BASIC_AUTH_USER="$2"
      shift 2
      ;;
    --basic-auth-password)
      BASIC_AUTH_PASSWORD="$2"
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
    --guided)
      GUIDED=1
      shift
      ;;
    --prepare-only)
      PREPARE_ONLY=1
      SKIP_INSTALL=1
      shift
      ;;
    --skip-https)
      AUTO_ENABLE_HTTPS=0
      shift
      ;;
    --skip-install)
      SKIP_INSTALL=1
      shift
      ;;
    --skip-verify)
      SKIP_VERIFY=1
      shift
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

prompt_value() {
  local var_name="$1"
  local label="$2"
  local default_value="${3:-}"
  local answer

  if [[ -n "${default_value}" ]]; then
    read -r -p "${label} [${default_value}]: " answer </dev/tty
    printf -v "${var_name}" '%s' "${answer:-${default_value}}"
  else
    read -r -p "${label}: " answer </dev/tty
    printf -v "${var_name}" '%s' "${answer}"
  fi
}

prompt_secret() {
  local var_name="$1"
  local label="$2"
  local answer

  read -r -s -p "${label}: " answer </dev/tty
  printf '\n' >/dev/tty
  printf -v "${var_name}" '%s' "${answer}"
}

prompt_yes_no() {
  local var_name="$1"
  local label="$2"
  local default_value="${3:-y}"
  local answer
  local prompt_suffix

  if [[ "${default_value}" == "y" ]]; then
    prompt_suffix="Y/n"
  else
    prompt_suffix="y/N"
  fi

  read -r -p "${label} [${prompt_suffix}]: " answer </dev/tty
  answer="${answer:-${default_value}}"
  case "${answer}" in
    y|Y|yes|YES)
      printf -v "${var_name}" '%s' "1"
      ;;
    *)
      printf -v "${var_name}" '%s' "0"
      ;;
  esac
}

expand_user_path() {
  local value="$1"

  case "${value}" in
    "~")
      printf '%s\n' "${HOME}"
      ;;
    "~/"*)
      printf '%s/%s\n' "${HOME}" "${value#~/}"
      ;;
    *)
      printf '%s\n' "${value}"
      ;;
  esac
}

if [[ "${GUIDED}" -eq 1 ]]; then
  if [[ ! -r /dev/tty ]]; then
    echo "--guided は対話入力できる端末で実行してください。" >&2
    exit 1
  fi

  cat >/dev/tty <<'EOF'
対話式セットアップを開始します。
分からない項目は Enter で既定値を使えます。
EOF

  while [[ -z "${DOMAIN}" ]]; do
    prompt_value DOMAIN "公開ドメイン名" "${DOMAIN}"
  done

  ROOT_HOST="${ROOT_HOST:-${DOMAIN}}"
  LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@${DOMAIN}}"
  HOST_DATA_ROOT="${HOST_DATA_ROOT:-~/docker-data}"
  RECORDED_ROOT="${RECORDED_ROOT:-~/recorded}"
  if [[ "${AUTO_ENABLE_HTTPS}" -eq 1 && "${PUBLIC_SCHEME}" == "http" ]]; then
    PUBLIC_SCHEME="https"
  fi

  prompt_value ROOT_HOST "WordPress を出すルートホスト名" "${ROOT_HOST}"
  prompt_value LETSENCRYPT_EMAIL "Let's Encrypt 通知メール" "${LETSENCRYPT_EMAIL}"
  prompt_value PUBLIC_SCHEME "公開URLの方式 http または https" "${PUBLIC_SCHEME}"
  cat >/dev/tty <<'EOF'
永続データの親ディレクトリ:
  各DockerのDB、設定、アップロードファイルなどを保存する場所です。
  例: ~/docker-data
  `~/` は使えます。保存時は /home/... の絶対パスへ変換します。

録画ファイルの親ディレクトリ:
  EPGStation の録画ファイルを保存する場所です。
  例: ~/recorded
  録画系を使わない場合でも、そのまま Enter で問題ありません。
EOF
  prompt_value HOST_DATA_ROOT "永続データの親ディレクトリ" "${HOST_DATA_ROOT}"
  prompt_value RECORDED_ROOT "録画ファイルの親ディレクトリ" "${RECORDED_ROOT}"
  HOST_DATA_ROOT="$(expand_user_path "${HOST_DATA_ROOT}")"
  RECORDED_ROOT="$(expand_user_path "${RECORDED_ROOT}")"
  prompt_value BASIC_AUTH_USER "管理画面 Basic 認証ユーザー名" "${BASIC_AUTH_USER}"
  if [[ -z "${BASIC_AUTH_PASSWORD}" ]]; then
    prompt_secret BASIC_AUTH_PASSWORD "管理画面 Basic 認証パスワード。空なら自動生成"
  fi
  if [[ -z "${OPENVPN_ADMIN_PASSWORD}" ]]; then
    prompt_secret OPENVPN_ADMIN_PASSWORD "OpenVPN 管理者パスワード。空なら自動生成"
  fi
  cat >/dev/tty <<'EOF'
インストールしないDocker:
  ここには「今回は入れないサービス名」を空白区切りで書きます。
  空のまま Enter なら全部入れます。

  指定できる例:
    infra-munin app-openvpn app-syncthing app-mirakurun-epgstation

  例:
    app-openvpn app-syncthing
EOF
  prompt_value EXCLUDED_SERVICES "インストールしないDocker。空なら全部対象" "${EXCLUDED_SERVICES}"

  if [[ "${PREPARE_ONLY}" -eq 0 ]]; then
    install_now=1
    prompt_yes_no install_now "このままインストールと起動確認まで進めますか" "y"
    if [[ "${install_now}" -eq 0 ]]; then
      SKIP_INSTALL=1
    fi
  else
    SKIP_INSTALL=1
  fi
fi

if [[ "${PREPARE_ONLY}" -eq 0 && "${GUIDED}" -eq 0 && -z "${DOMAIN}" ]]; then
  echo "--guided または --prepare-only を使わない場合は --domain が必要です。" >&2
  exit 1
fi

if [[ "${STACK_GITHUB_OWNER}" == "your-github-user" ]]; then
  echo "--owner が必要です。GitHub のユーザー名または owner 名を指定してください。" >&2
  exit 1
fi

if ! grep -qi 'ubuntu' /etc/os-release 2>/dev/null; then
  echo "この bootstrap スクリプトは現在 Ubuntu ホストを前提にしています。" >&2
  exit 1
fi

if [[ -n "${DOMAIN}" ]]; then
  ROOT_HOST="${ROOT_HOST:-${DOMAIN}}"
  LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@${DOMAIN}}"
fi

sudo -v

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y ca-certificates curl git docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker "${USER}"

random_secret_local() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 32
    printf '\n'
  fi
}

if [[ "${GUIDED}" -eq 1 ]]; then
  BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-$(random_secret_local)}"
  OPENVPN_ADMIN_PASSWORD="${OPENVPN_ADMIN_PASSWORD:-$(random_secret_local)}"
fi

mkdir -p "${STACK_ROOT}"

if [[ ! -d "${INSTALLER_DIR}/.git" ]]; then
  case "${CLONE_PROTOCOL}" in
    ssh)
      git clone "git@github.com:${STACK_GITHUB_OWNER}/docker-stack-installer.git" "${INSTALLER_DIR}"
      ;;
    https)
      git clone "https://github.com/${STACK_GITHUB_OWNER}/docker-stack-installer.git" "${INSTALLER_DIR}"
      ;;
    *)
      echo "未対応の clone 方式です: ${CLONE_PROTOCOL}" >&2
      exit 1
      ;;
  esac
else
  git -C "${INSTALLER_DIR}" pull --ff-only
fi

cat >"${INSTALLER_DIR}/stack.env.local" <<EOF
STACK_ROOT=${STACK_ROOT}
STACK_GITHUB_OWNER=${STACK_GITHUB_OWNER}
CLONE_PROTOCOL=${CLONE_PROTOCOL}
EXCLUDED_SERVICES="${EXCLUDED_SERVICES}"
AUTO_ENABLE_HTTPS=${AUTO_ENABLE_HTTPS}
EOF

env_set_file_local() {
  local file_path="$1"
  local key="$2"
  local value="$3"

  [[ -n "${value}" ]] || return 0

  if grep -qE "^${key}=" "${file_path}" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${file_path}"
  else
    printf '%s=%s\n' "${key}" "${value}" >>"${file_path}"
  fi
}

run_with_docker_group() {
  local command_string="$1"
  local wrapper_dir
  if docker info >/dev/null 2>&1; then
    bash -lc "${command_string}"
  elif command -v sg >/dev/null 2>&1; then
    sg docker -c "${command_string}"
  else
    wrapper_dir="$(mktemp -d)"
    cat >"${wrapper_dir}/docker" <<'EOF'
#!/usr/bin/env bash
exec sudo docker "$@"
EOF
    chmod +x "${wrapper_dir}/docker"
    set +e
    PATH="${wrapper_dir}:${PATH}" bash -lc "${command_string}"
    local command_status=$?
    set -e
    rm -rf "${wrapper_dir}"
    return "${command_status}"
  fi
}

shell_quote() {
  printf '%q' "$1"
}

repo_cmd_prefix="cd $(shell_quote "${INSTALLER_DIR}")"
configure_cmd="${repo_cmd_prefix} && ./scripts/configure-default-envs.sh --domain $(shell_quote "${DOMAIN}") --root-host $(shell_quote "${ROOT_HOST}") --email $(shell_quote "${LETSENCRYPT_EMAIL}") --public-scheme $(shell_quote "${PUBLIC_SCHEME}") --excluded-services $(shell_quote "${EXCLUDED_SERVICES}") --basic-auth-user $(shell_quote "${BASIC_AUTH_USER}")"
if [[ -n "${BASIC_AUTH_PASSWORD}" ]]; then
  configure_cmd="${configure_cmd} --basic-auth-password $(shell_quote "${BASIC_AUTH_PASSWORD}")"
fi
if [[ -n "${OPENVPN_ADMIN_PASSWORD}" ]]; then
  configure_cmd="${configure_cmd} --openvpn-admin-password $(shell_quote "${OPENVPN_ADMIN_PASSWORD}")"
fi

run_with_docker_group "${repo_cmd_prefix} && ./scripts/bootstrap-repos.sh"
run_with_docker_group "${repo_cmd_prefix} && ./scripts/init-env-files.sh"

if [[ "${GUIDED}" -eq 1 ]]; then
  unified_env_path="${INSTALLER_DIR}/stack.service.env.local"
  env_set_file_local "${unified_env_path}" "GLOBAL__DOMAIN" "${DOMAIN}"
  env_set_file_local "${unified_env_path}" "GLOBAL__ROOT_HOST" "${ROOT_HOST}"
  env_set_file_local "${unified_env_path}" "GLOBAL__PUBLIC_SCHEME" "${PUBLIC_SCHEME}"
  env_set_file_local "${unified_env_path}" "GLOBAL__LETSENCRYPT_EMAIL" "${LETSENCRYPT_EMAIL}"
  env_set_file_local "${unified_env_path}" "GLOBAL__BASIC_AUTH_USER" "${BASIC_AUTH_USER}"
  env_set_file_local "${unified_env_path}" "GLOBAL__BASIC_AUTH_PASSWORD" "${BASIC_AUTH_PASSWORD}"
  env_set_file_local "${unified_env_path}" "GLOBAL__HOST_DATA_ROOT" "${HOST_DATA_ROOT}"
  env_set_file_local "${unified_env_path}" "GLOBAL__RECORDED_ROOT" "${RECORDED_ROOT}"
  env_set_file_local "${unified_env_path}" "GLOBAL__PROXY_NETWORK_NAME" "proxy-network"
  env_set_file_local "${unified_env_path}" "GLOBAL__PROXY_LOG_DIR" "${STACK_ROOT%/}/infra-reverse-proxy/data/log"
fi

if [[ "${PREPARE_ONLY}" -eq 0 ]]; then
  run_with_docker_group "${configure_cmd}"
fi

run_with_docker_group "${repo_cmd_prefix} && ./scripts/doctor.sh"

if [[ "${PREPARE_ONLY}" -eq 1 ]]; then
  cat <<EOF
準備が完了しました。

インストーラ repo:
  ${INSTALLER_DIR}

次の手順:
  cd ${INSTALLER_DIR}
  stack.env.local と stack.service.env.local を編集
  ./scripts/run-full-stack.sh
EOF
  exit 0
fi

if [[ "${SKIP_INSTALL}" -eq 0 ]]; then
  run_command="${repo_cmd_prefix} && ./scripts/run-full-stack.sh --skip-bootstrap --skip-init-env"
  if [[ "${SKIP_VERIFY}" -eq 1 ]]; then
    run_command="${run_command} --skip-verify"
  fi
  run_with_docker_group "${run_command}"
fi

cat <<EOF
Bootstrap が完了しました。

インストーラ repo:
  ${INSTALLER_DIR}

次によく使うコマンド:
  cd ${INSTALLER_DIR}
  ./scripts/run-full-stack.sh
EOF
