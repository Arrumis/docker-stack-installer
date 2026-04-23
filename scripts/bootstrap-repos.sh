#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

mkdir -p "${STACK_ROOT}"

github_token() {
  if [[ -f "${HOME}/.config/gh/hosts.yml" ]]; then
    awk '/oauth_token:/{print $2; exit}' "${HOME}/.config/gh/hosts.yml"
    return 0
  fi

  return 1
}

git_with_auth() {
  local token

  if [[ "${CLONE_PROTOCOL}" != "https" ]]; then
    git "$@"
    return
  fi

  if token="$(github_token)" && [[ -n "${token}" ]]; then
    git -c "url.https://x-access-token:${token}@github.com/.insteadOf=https://github.com/" "$@"
    return
  fi

  git "$@"
}

clone_repo() {
  local service_name="$1"
  local service_dir="$2"
  local repo_url
  repo_url="$(service_repo_url "${service_name}")"

  if command -v gh >/dev/null 2>&1; then
    gh repo clone "${STACK_GITHUB_OWNER}/$(basename "${service_dir}")" "${service_dir}"
  else
    git_with_auth clone "${repo_url}" "${service_dir}"
  fi
}

update_repo() {
  local service_dir="$1"
  git_with_auth -C "${service_dir}" pull --ff-only
}

while IFS= read -r service_name; do
  service_dir="$(service_abs_dir "${service_name}")"

  if [[ ! -d "${service_dir}/.git" ]]; then
    echo "== cloning ${service_name} =="
    clone_repo "${service_name}" "${service_dir}"
    continue
  fi

  echo "== updating ${service_name} =="
  update_repo "${service_dir}"
done < <(list_target_services "$@")
