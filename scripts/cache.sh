#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${1:-${ROOT:-/media/fat}}"
GAMES_ROOT="${GAMES_ROOT:-${ROOT%/}/games}"
CACHE_FILE="${CACHE_FILE:-${SCRIPT_DIR}/.cache}"
LOG_FILE="${MISTER_SIMP_LOG_FILE:-${SCRIPT_DIR}/.log}"

mkdir -p "${LOG_FILE%/*}"
exec 2>>"$LOG_FILE"

stage() {
	printf '\n==> %s\n' "$1"
	printf 'stage: %s\n' "$1" >>"$LOG_FILE"
}

stage 'cache'

core_for_file() {
	local rel="$1"
	local folder="${rel%%/*}"
	local ext="${rel##*.}"
	ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

	case "${folder}:${ext}" in
		Gameboy:gb|Gameboy:gbc) printf 'Gameboy\n' ;;
		GBA:gba) printf 'GBA\n' ;;
		NES:nes|NES:fds) printf 'NES\n' ;;
		SNES:sfc|SNES:smc|SNES:bin|SNES:bs) printf 'SNES\n' ;;
		N64:n64|N64:z64) printf 'N64\n' ;;
		SMS:sms|SMS:gg) printf 'SMS\n' ;;
		MegaDrive:bin|MegaDrive:gen|MegaDrive:md) printf 'MegaDrive\n' ;;
		MegaCD:cue|MegaCD:chd) printf 'MegaCD\n' ;;
		NeoGeo:neo|NeoGeo-CD:cue|NeoGeo-CD:chd) printf 'NeoGeo\n' ;;
		TGFX16:bin|TGFX16:pce|TGFX16-CD:cue|TGFX16-CD:chd) printf 'TurboGrafx16\n' ;;
		PSX:cue|PSX:chd|PSX:exe) printf 'PSX\n' ;;
		Saturn:cue|Saturn:chd) printf 'Saturn\n' ;;
		*) return 1 ;;
	esac
}

build_cache() {
	local tmp="${CACHE_FILE}.tmp"
	local folder file rel base core count
	: > "$tmp"
	for folder in \
		Gameboy \
		GBA \
		MegaCD \
		MegaDrive \
		N64 \
		NeoGeo \
		NeoGeo-CD \
		NES \
		PSX \
		S32X \
		Saturn \
		SMS \
		SNES \
		TGFX16 \
		TGFX16-CD
	do
		stage "$folder"
		while IFS= read -r -d '' file; do
			rel="${file#$GAMES_ROOT/}"
			base="${rel##*/}"
			case "$base" in
				.*|._*) continue ;;
			esac
			case "$base" in
				*"Disc 2"*|*"Disc 3"*|*"Disc 4"*|*"Disc 5"*) continue ;;
			esac
			if core="$(core_for_file "$rel")"; then
				case "${rel%%/*}" in
					"$folder")
						printf '%s\t%s\n' "$rel" "$core" >> "$tmp"
						printf 'processing: %s\n' "$rel" >>"$LOG_FILE"
						;;
				esac
			fi
		done < <(find "$GAMES_ROOT/$folder" -type f -print0 2>/dev/null)
	done
	rm -f "$CACHE_FILE"
	mv "$tmp" "$CACHE_FILE"
}

build_cache
printf 'done\n'
