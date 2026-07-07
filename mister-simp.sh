#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-/media/fat}"
ROOT_DIR="${ROOT%/}"
SCRIPTS_ROOT="${ROOT_DIR}/scripts"
script_name="${0##*/}"
REPO_BASE_URL="${REPO_BASE_URL:-https://raw.githubusercontent.com/lplvlql/mister-simp/refs/heads/main}"
LOG_FILE="${SCRIPTS_ROOT}/.log"

ROOT_FILES=(
  "MiSTer"
  "menu.rbf"
)

SCRIPTS_FILES=(
  clean.sh
  cache.sh
  delete.sh
  last.sh
  random.sh
  update.sh
)

require_root_file() {
  local name="$1"
  if [[ ! -e "${ROOT_DIR}/${name}" ]]; then
    echo "missing required file: $name" >&2
    exit 1
  fi
}

install_payload() {
  mkdir -p "$SCRIPTS_ROOT"
  local name
  for name in "${SCRIPTS_FILES[@]}"; do
    fetch_script "scripts/$name" "${SCRIPTS_ROOT}/$name"
  done
  chmod +x "${SCRIPTS_ROOT}"/*.sh
}

fetch_script() {
  local remote_path="$1"
  local dest="$2"
  local url="${REPO_BASE_URL}/${remote_path}"
  local tmp="${dest}.tmp"

  if [[ "$url" == file://* ]]; then
    local source_path="${url#file://}"
    cp "$source_path" "$tmp"
  elif command -v curl >/dev/null 2>&1; then
    curl -kfsSL "$url" -o "$tmp"
  else
    echo "curl is required to fetch scripts: $url" >&2
    exit 1
  fi

  mv -f "$tmp" "$dest"
}

cleanup_bootstrap_scripts() {
  local entry
  [[ -d "$SCRIPTS_ROOT" ]] || return 0
  for entry in "${SCRIPTS_ROOT}"/*; do
    [[ -e "$entry" ]] || continue
    local name keep=0
    name="${entry##*/}"
    for script in "${SCRIPTS_FILES[@]}"; do
      if [[ "$name" == "$script" ]]; then
        keep=1
        break
      fi
    done
    if [[ "$keep" -eq 0 ]]; then
      rm -rf "$entry"
    fi
  done
}

ensure_bootstrap_scripts() {
  mkdir -p "$SCRIPTS_ROOT"
  local name
  for name in "${SCRIPTS_FILES[@]}"; do
    [[ -x "${SCRIPTS_ROOT}/${name}" ]] || return 1
  done
}

main() {
  mkdir -p "$SCRIPTS_ROOT"
  export MISTER_SIMP_LOG_FILE="$LOG_FILE"
  mkdir -p "${LOG_FILE%/*}"
  exec 2>>"$LOG_FILE"
  run_stamp="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '==> migrate\n'
  printf 'run: %s\n' "$run_stamp" >>"$LOG_FILE"
  for name in "${ROOT_FILES[@]}"; do
    require_root_file "$name"
  done
  install_payload
  ensure_bootstrap_scripts
  cleanup_bootstrap_scripts
  "${SCRIPTS_ROOT}/clean.sh" "$ROOT_DIR"
  "${SCRIPTS_ROOT}/update.sh" "$ROOT_DIR"
  "${SCRIPTS_ROOT}/cache.sh" "$ROOT_DIR"
  rm -f "${SCRIPTS_ROOT}/${script_name}"
  printf 'migration complete\n'
}

main
