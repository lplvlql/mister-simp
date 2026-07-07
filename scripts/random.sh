#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-${ROOT:-/media/fat}}"
GAMES_ROOT="${GAMES_ROOT:-${ROOT%/}/games}"
CACHE_FILE="${CACHE_FILE:-${SCRIPT_DIR}/.cache}"
MGL_FILE="${MGL_FILE:-${SCRIPT_DIR}/.mgl}"
LOG_FILE="${MISTER_SIMP_LOG_FILE:-${SCRIPT_DIR}/.log}"
MISTER_CMD="${MISTER_CMD:-/dev/MiSTer_cmd}"

mkdir -p "${LOG_FILE%/*}"
exec 2>>"$LOG_FILE"

stage() {
	printf '\n==> %s\n' "$1"
	printf 'stage: %s\n' "$1" >>"$LOG_FILE"
}

stage 'random'

params_for_file() {
	local rel="$1"
	local folder="${rel%%/*}"
	local ext="${rel##*.}"
	ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

	case "${folder}:${ext}" in
		Gameboy:gb|Gameboy:gbc|GBA:gba|NES:nes|NES:fds)
			printf 'f 1 2\n'
			;;
		SNES:sfc|SNES:smc|SNES:bin|SNES:bs)
			printf 'f 0 2\n'
			;;
		TGFX16:bin|TGFX16:pce)
			printf 'f 0 1\n'
			;;
		MegaDrive:bin|MegaDrive:gen|MegaDrive:md|S32X:32x|SMS:sms|N64:n64|N64:z64|NeoGeo:neo)
			printf 'f 1 1\n'
			;;
		MegaCD:cue|MegaCD:chd|Saturn:cue|Saturn:chd|PSX:cue|PSX:chd|PSX:exe)
			printf 's 0 1\n'
			;;
		TGFX16-CD:cue|TGFX16-CD:chd|NeoGeo-CD:cue|NeoGeo-CD:chd)
			printf 's 1 1\n'
			;;
		*)
			return 1
			;;
	esac
}

xml_escape() {
	local s="$1"
	s="${s//&/&amp;}"
	s="${s//</&lt;}"
	s="${s//>/&gt;}"
	s="${s//\"/&quot;}"
	printf '%s' "$s"
}

build_mgl() {
	local core="$1"
	local rel="$2"
	local file="${GAMES_ROOT%/}/${rel}"
	local type
	local index
	local delay

	read -r type index delay <<<"$(params_for_file "$rel")"

	cat >"$MGL_FILE" <<EOF
<mistergamedescription>
  <rbf>$(xml_escape "$core")</rbf>
  <file delay="${delay}" type="${type}" index="${index}" path="$(xml_escape "${file}")"/>
</mistergamedescription>
EOF
	printf '%s\n' "$MGL_FILE"
}

if [[ ! -s "$CACHE_FILE" ]]; then
	echo "No cache found at ${CACHE_FILE}" >&2
	exit 1
fi

declare -a games=()
while IFS= read -r line; do
	games+=("$line")
done < "$CACHE_FILE"

if (( ${#games[@]} == 0 )); then
	echo "No launchable games found under $GAMES_ROOT" >&2
	exit 1
fi

choice="${games[$((RANDOM % ${#games[@]}))]}"
rel="${choice%%$'\t'*}"
core="${choice#*$'\t'}"

printf 'picked: %s\n' "$rel" >>"$LOG_FILE"

mgl="$(build_mgl "$core" "$rel")"
printf 'load_core %s\n' "$mgl" > "$MISTER_CMD"
printf 'done\n'
