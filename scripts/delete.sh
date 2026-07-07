#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-${ROOT:-/media/fat}}"
GAMES_ROOT="${GAMES_ROOT:-${ROOT%/}/games}"
MGL_FILE="${MGL_FILE:-${SCRIPT_DIR}/.mgl}"
LOG_FILE="${MISTER_SIMP_LOG_FILE:-${SCRIPT_DIR}/.log}"

mkdir -p "${LOG_FILE%/*}"
exec 2>>"$LOG_FILE"

stage() {
	printf '\n==> %s\n' "$1"
	printf 'stage: %s\n' "$1" >>"$LOG_FILE"
}

stage 'delete'

if [[ ! -f "$MGL_FILE" ]]; then
	echo "No saved MGL found at ${MGL_FILE}" >&2
	exit 1
fi

rel="$(sed -n 's/.*path="\([^"]*\)".*/\1/p' "$MGL_FILE" | head -n 1)"
if [[ -z "$rel" ]]; then
	echo "Saved MGL does not contain a target path" >&2
	exit 1
fi

if [[ "$rel" != "$GAMES_ROOT/"* ]]; then
	echo "Saved MGL points outside games: ${rel}" >&2
	exit 1
fi

if [[ ! -f "$rel" ]]; then
	echo "Saved game is missing: ${rel}" >&2
	rm -f "$MGL_FILE"
	exit 1
fi

rm -f "$rel"
rm -f "$MGL_FILE"

printf 'deleted: %s\n' "$rel" >>"$LOG_FILE"
printf 'done\n'
