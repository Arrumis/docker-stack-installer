#!/usr/bin/env bash
set -euo pipefail

# env 編集後に実行するための入口です。
# インストール本体、起動後確認、設定一覧の出力を 1 本にまとめ、手順の迷子を防ぎます。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKIP_VERIFY=0
INSTALL_ARGS=()
LOG_DIR="${LOG_DIR:-${REPO_ROOT}/logs}"
LOG_FILE="${LOG_FILE:-}"
RUN_FULL_STACK_LOGGING="${RUN_FULL_STACK_LOGGING:-0}"

if [[ "${RUN_FULL_STACK_LOGGING}" -eq 0 ]]; then
  mkdir -p "${LOG_DIR}"
  LOG_FILE="${LOG_FILE:-${LOG_DIR}/install-$(date '+%Y%m%d-%H%M%S').log}"
  echo "インストールログを保存します: ${LOG_FILE}"
  RUN_FULL_STACK_LOGGING=1 LOG_FILE="${LOG_FILE}" "$0" "$@" 2>&1 | tee "${LOG_FILE}"
  exit "${PIPESTATUS[0]}"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-verify)
      SKIP_VERIFY=1
      shift
      ;;
    *)
      INSTALL_ARGS+=("$1")
      shift
      ;;
  esac
done

cd "${REPO_ROOT}"

echo "== docker-stack install log =="
echo "開始日時: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "作業ディレクトリ: ${REPO_ROOT}"
echo "ログファイル: ${LOG_FILE}"

./scripts/install-full-stack.sh "${INSTALL_ARGS[@]}"
./scripts/write-install-summary.sh

if [[ "${SKIP_VERIFY}" -eq 0 ]]; then
  ./scripts/verify-stack.sh
fi

echo "終了日時: $(date '+%Y-%m-%d %H:%M:%S %z')"
