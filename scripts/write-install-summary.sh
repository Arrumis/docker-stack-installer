#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

OUTPUT_FILE="${OUTPUT_FILE:-${REPO_ROOT}/local-install-summary.md}"

markdown_cell() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//|/\\|}"
  printf '%s' "${value}"
}

write_env_table() {
  local title="$1"
  local file_path="$2"
  local key
  local value

  {
    printf '## %s\n\n' "${title}"

    if [[ ! -f "${file_path}" ]]; then
      printf '対象ファイルがありません: `%s`\n\n' "${file_path}"
      return 0
    fi

    printf '対象ファイル: `%s`\n\n' "${file_path}"
    printf '| 項目 | 値 |\n'
    printf '|---|---|\n'

    while IFS='=' read -r key value; do
      [[ -n "${key}" ]] || continue
      [[ "${key}" =~ ^[[:space:]]*# ]] && continue
      [[ "${key}" =~ ^[[:space:]]*$ ]] && continue
      printf '| `%s` | `%s` |\n' "$(markdown_cell "${key}")" "$(markdown_cell "${value}")"
    done <"${file_path}"

    printf '\n'
  } >>"${OUTPUT_FILE}"
}

write_ttrss_admin_password() {
  local password_file

  if ! service_is_selected "app-ttrss"; then
    return 0
  fi

  password_file="$(service_abs_dir "app-ttrss")/ttrss_admin_password.txt"

  {
    printf '## ttrss 初期 admin ログイン情報\n\n'
    printf 'ttrss の初回ログインや復旧で使う admin 情報です。\n\n'

    if [[ ! -f "${password_file}" ]]; then
      printf 'パスワードファイルがまだありません: `%s`\n\n' "${password_file}"
      printf '通常は `app-ttrss/scripts/capture-admin-password.sh` が起動後に作成します。\n\n'
      return 0
    fi

    printf '対象ファイル: `%s`\n\n' "${password_file}"
    printf '| 項目 | 値 |\n'
    printf '|---|---|\n'

    while IFS='=' read -r key value; do
      [[ -n "${key}" ]] || continue
      [[ "${key}" =~ ^[[:space:]]*# ]] && continue
      [[ "${key}" =~ ^[[:space:]]*$ ]] && continue
      printf '| `%s` | `%s` |\n' "$(markdown_cell "${key}")" "$(markdown_cell "${value}")"
    done <"${password_file}"

    printf '\n'
  } >>"${OUTPUT_FILE}"
}

{
  printf '# インストール設定一覧\n\n'
  printf 'このファイルは、このPCへインストールしたときの設定控えです。\n'
  printf 'GitHubへ上げないローカル専用ファイルです。\n\n'
  printf '%s\n' "- 作成日時: \`$(date '+%Y-%m-%d %H:%M:%S %z')\`"
  printf '%s\n' "- 親 repo: \`${REPO_ROOT}\`"
  printf '%s\n\n' "- stack root: \`${STACK_ROOT}\`"
  printf '注意: パスワード忘れに備えるため、このファイルにはパスワードなどの秘密情報も実値で記録します。\n'
  printf 'GitHubへ上げず、このPC内の復旧用控えとして扱ってください。\n'
  printf 'ファイル権限は作成後に owner だけ読める `600` へ変更します。\n\n'
} >"${OUTPUT_FILE}"

write_env_table "親 repo の基本設定" "${STACK_ENV_FILE}"
write_env_table "統括 env" "${UNIFIED_ENV_FILE}"

printf '## サービス別 env\n\n' >>"${OUTPUT_FILE}"

mapfile -t target_services < <(list_target_services)

service_is_selected() {
  local target="$1"
  local service_name

  for service_name in "${target_services[@]}"; do
    if [[ "${service_name}" == "${target}" ]]; then
      return 0
    fi
  done

  return 1
}

while IFS=$'\t' read -r service_name repo_dir env_file compose_override legacy_compose_file; do
  [[ -n "${service_name}" ]] || continue
  if ! service_is_selected "${service_name}"; then
    continue
  fi

  service_dir="$(service_abs_dir "${service_name}")"
  write_env_table "${service_name}" "${service_dir}/${env_file}"
done < <(load_services)

write_ttrss_admin_password

cat <<EOF
インストール設定一覧を出力しました。
  ${OUTPUT_FILE}
EOF

chmod 600 "${OUTPUT_FILE}"
