#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

OUTPUT_FILE="${OUTPUT_FILE:-${REPO_ROOT}/local-install-summary.md}"

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
      printf '| `%s` | `%s` |\n' "${key}" "${value}"
    done <"${file_path}"

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
  printf '注意: このファイルにはパスワードなどの秘密情報が含まれる場合があります。\n'
  printf 'GitHubへ上げず、このPC内の控えとして扱ってください。\n\n'
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

cat <<EOF
インストール設定一覧を出力しました。
  ${OUTPUT_FILE}
EOF
