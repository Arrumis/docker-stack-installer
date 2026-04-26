#!/usr/bin/env bash
set -euo pipefail

# env 編集後に実行するための入口です。
# インストール本体、起動後確認、設定一覧の出力を 1 本にまとめ、手順の迷子を防ぎます。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKIP_VERIFY=0
INSTALL_ARGS=()

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

./scripts/install-full-stack.sh "${INSTALL_ARGS[@]}"
./scripts/write-install-summary.sh

if [[ "${SKIP_VERIFY}" -eq 0 ]]; then
  ./scripts/verify-stack.sh
fi
