#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-${ROOT:-/media/fat}}"
MGL_FILE="${MGL_FILE:-${SCRIPT_DIR}/.mgl}"
LOG_FILE="${MISTER_SIMP_LOG_FILE:-${SCRIPT_DIR}/.log}"
MISTER_CMD="${MISTER_CMD:-/dev/MiSTer_cmd}"

mkdir -p "${LOG_FILE%/*}"
exec 2>>"$LOG_FILE"

stage() {
	printf '\n==> %s\n' "$1"
	printf 'stage: %s\n' "$1" >>"$LOG_FILE"
}

stage 'last'

if [[ ! -f "$MGL_FILE" ]]; then
	echo "No saved MGL found at ${MGL_FILE}" >&2
	exit 1
fi

printf 'load_core %s\n' "$MGL_FILE" > "$MISTER_CMD"
printf 'done\n'
