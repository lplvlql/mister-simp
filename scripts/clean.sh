#!/bin/bash

set -euo pipefail

ROOT="${1:-${ROOT:-/media/fat}}"
ROOT_PATH="${ROOT%/}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${MISTER_SIMP_LOG_FILE:-${SCRIPT_DIR}/.log}"

mkdir -p "${LOG_FILE%/*}"
exec 2>>"$LOG_FILE"

stage() {
  printf '\n==> %s\n' "$1"
  printf 'stage: %s\n' "$1" >>"$LOG_FILE"
}

ROOT_FILES=(
  "MiSTer"
  "menu.rbf"
)

ROOT_INI_PREFIXES=(
  "MiSTer"
)

CORE_NAMES=(
  "GBA"
  "Gameboy"
  "MegaCD"
  "MegaDrive"
  "N64"
  "NES"
  "NeoGeo"
  "PSX"
  "S32X"
  "Saturn"
  "SMS"
  "SNES"
  "TurboGrafx16"
)

ROOT_DIRS=(
  "config"
  "games"
  "linux"
  "saves"
  "savestates"
  "scripts"
)

SCRIPTS_FILES=(
  "cache.sh"
  "clean.sh"
  "delete.sh"
  "last.sh"
  "random.sh"
  "update.sh"
)

GAME_DIRS=(
  "GBA"
  "Gameboy"
  "MegaCD"
  "MegaDrive"
  "N64"
  "NES"
  "NeoGeo-CD"
  "NeoGeo"
  "NeoGeoPocket"
  "PSX"
  "S32X"
  "SMS"
  "SNES"
  "Saturn"
  "TGFX16"
  "TGFX16-CD"
)

GAME_BLACKLIST=(
  "Gameboy/Palettes"
  "NES/Palettes"
  "PSX/240p Test Suite"
  "PSX/PadTest 1.1"
  "SNES/240p Test Suite"
  "MegaDrive/240p Test Suite.bin"
  "N64/N64 Controller Tester.z64"
  "NeoGeo/gog-romsets.xml"
  "NeoGeo/gog-broken-romsets.xml"
  "NeoGeoPocket/.delme"
)

lowercase() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

case_only_rename() {
  local entry="$1"
  local dst="$2"
  local base="${entry##*/}"
  local tmp="${entry%/*}/.${base}"

  mv "$entry" "$tmp"
  rm -rf "$dst"
  mv "$tmp" "$dst"
}

move_or_rename() {
  local entry="$1"
  local dst="$2"

  if [[ "$(lowercase "${entry##*/}")" == "$(lowercase "${dst##*/}")" ]]; then
    case_only_rename "$entry" "$dst"
  else
    rm -rf "$dst"
    mv "$entry" "$dst"
  fi
}

canonical_from_whitelist() {
  local name="$1"
  shift
  local allowed
  for allowed in "$@"; do
    if [[ "$(lowercase "$name")" == "$(lowercase "$allowed")" ]]; then
      printf '%s\n' "$allowed"
      return 0
    fi
  done
  return 1
}

normalize_root() {
  local entry base dst
  for entry in "${ROOT_PATH}"/* "${ROOT_PATH}"/.*; do
    [[ -e "$entry" ]] || continue
    case "${entry##*/}" in
      .|..) continue ;;
    esac
    base="${entry##*/}"
    if ! dst="$(canonical_from_whitelist "$base" "${ROOT_DIRS[@]}")"; then
      continue
    fi
    dst="${ROOT_PATH}/${dst}"
    if [[ "$entry" != "$dst" ]]; then
      move_or_rename "$entry" "$dst"
    fi
  done
}

prune_root() {
  local entry base keep prefix
  for entry in "${ROOT_PATH}"/* "${ROOT_PATH}"/.*; do
    [[ -e "$entry" ]] || continue
    case "${entry##*/}" in
      .|..) continue ;;
    esac
    base="${entry##*/}"
    keep=0
    for allowed in "${ROOT_FILES[@]}" "${ROOT_DIRS[@]}"; do
      if [[ "$base" == "$allowed" ]]; then
        keep=1
        break
      fi
    done
    case "$base" in
      *.ini)
        if [[ "$keep" -eq 1 ]]; then
          continue
        fi
        for prefix in "${ROOT_INI_PREFIXES[@]}"; do
          if [[ "$base" == "${prefix}"* ]]; then
            keep=1
            break
          fi
        done
        ;;
      *.rbf)
        if [[ "$keep" -eq 1 ]]; then
          continue
        fi
        keep=0
        for prefix in "${CORE_NAMES[@]}"; do
          if [[ "$base" == "${prefix}"_*".rbf" ]]; then
            keep=1
            break
          fi
        done
        ;;
    esac
    if [[ "$keep" -eq 0 ]]; then
      rm -rf "$entry"
    fi
  done
}

normalize_games() {
  local entry base dst
  for entry in "${ROOT_PATH}/games"/* "${ROOT_PATH}/games"/.*; do
    [[ -e "$entry" ]] || continue
    case "${entry##*/}" in
      .|..) continue ;;
    esac
    base="${entry##*/}"
    if ! dst="$(canonical_from_whitelist "$base" "${GAME_DIRS[@]}")"; then
      continue
    fi
    dst="${ROOT_PATH}/games/${dst}"
    if [[ "$entry" != "$dst" ]]; then
      move_or_rename "$entry" "$dst"
    fi
  done
}

normalize_scripts() {
  local entry base dst tmp
  for entry in "${ROOT_PATH}"/* "${ROOT_PATH}"/.*; do
    [[ -e "$entry" ]] || continue
    case "${entry##*/}" in
      .|..) continue ;;
    esac
    base="${entry##*/}"
    if ! dst="$(canonical_from_whitelist "$base" "scripts")"; then
      continue
    fi
    dst="${ROOT_PATH}/${dst}"
    if [[ "$entry" != "$dst" ]]; then
      move_or_rename "$entry" "$dst"
    fi
  done
}

prune_games() {
  local entry rel name keep banned
  if [[ -d "${ROOT_PATH}/games" ]]; then
    while IFS= read -r -d '' entry; do
      rel="${entry#${ROOT_PATH}/games/}"
      for banned in "${GAME_BLACKLIST[@]}"; do
        case "${rel}" in
          "${banned}"|"${banned}"/*)
            rm -rf "${entry}"
            continue 2
            ;;
        esac
      done
    done < <(for entry in "${ROOT_PATH}/games"/* "${ROOT_PATH}/games"/.*; do [[ -e "$entry" ]] && printf '%s\0' "$entry"; done)

    while IFS= read -r -d '' entry; do
      rel="${entry#${ROOT_PATH}/games/}"
      name="${rel%%/*}"
      keep=0
      for allowed in "${GAME_DIRS[@]}"; do
        if [[ "$(lowercase "$name")" == "$(lowercase "$allowed")" ]]; then
          keep=1
          break
        fi
      done
      if [[ "$keep" -eq 0 ]]; then
        rm -rf "${ROOT_PATH}/games/$name"
      fi
    done < <(for entry in "${ROOT_PATH}/games"/*; do [[ -d "$entry" ]] && printf '%s\0' "$entry"; done)
  fi
}

prune_scripts() {
  local entry name keep
  if [[ -d "${ROOT_PATH}/scripts" ]]; then
    while IFS= read -r -d '' entry; do
      name="${entry##*/}"
      keep=0
      for allowed in "${SCRIPTS_FILES[@]}"; do
        if [[ "$(lowercase "$name")" == "$(lowercase "$allowed")" ]]; then
          keep=1
          break
        fi
      done
      if [[ "$keep" -eq 0 ]]; then
        rm -rf "$entry"
      fi
    done < <(for entry in "${ROOT_PATH}/scripts"/* "${ROOT_PATH}/scripts"/.*; do [[ -e "$entry" ]] && printf '%s\0' "$entry"; done)
  fi
}

stage 'normalize root'
normalize_root
stage 'prune root'
prune_root
stage 'normalize games'
normalize_games
stage 'prune games'
prune_games
stage 'normalize scripts'
normalize_scripts
stage 'prune scripts'
prune_scripts

printf 'clean done\n'
