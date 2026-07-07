#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(cd -- "${SCRIPT_DIR}/.." && pwd)}"
SCRIPTS_ROOT="${ROOT%/}/scripts"
LOG_FILE="${MISTER_SIMP_LOG_FILE:-${SCRIPT_DIR}/.log}"
MANIFEST_FILE="${MANIFEST_FILE:-${SCRIPTS_ROOT}/.manifest}"

mkdir -p "${LOG_FILE%/*}"
exec 2>>"$LOG_FILE"

DIST_URL="${DIST_URL:-https://raw.githubusercontent.com/MiSTer-devel/Distribution_MiSTer/main/db.json.zip}"
BIOS_URL="${BIOS_URL:-https://raw.githubusercontent.com/ajgowans/BiosDB_MiSTer/db/bios_db.json}"
SCRIPTS_URL="${SCRIPTS_URL:-https://raw.githubusercontent.com/lplvlql/mister-simp/refs/heads/main/scripts}"

GAME_DIRS=(
  GBA
  Gameboy
  MegaCD
  MegaDrive
  N64
  NeoGeo-CD
  NeoGeoPocket
  NES
  NeoGeo
  PSX
  S32X
  Saturn
  SMS
  SNES
  TGFX16
  TGFX16-CD
)

CORE_NAMES=(
  GBA
  Gameboy
  MegaCD
  MegaDrive
  N64
  NeoGeo
  NES
  PSX
  S32X
  Saturn
  SMS
  SNES
  TurboGrafx16
)

ROOT_DIRS=(
  config
  games
  linux
  saves
  savestates
  scripts
)

ROOT_FILES=(
  MiSTer
  menu.rbf
)

SCRIPTS_FILES=(
  clean.sh
  cache.sh
  delete.sh
  last.sh
  random.sh
  update.sh
)

status() {
  printf 'processing: %s\n' "$1" >>"$LOG_FILE"
}

done_line() {
  printf '%s\n' "$1" >>"$LOG_FILE"
}

stage() {
  printf '\n==> %s\n' "$1"
  printf 'stage: %s\n' "$1" >>"$LOG_FILE"
}

read_manifest() {
  jq -r '.files | to_entries[] | [.key, (.value.hash // "")] | @tsv' <<<"$1"
}

manifest_base_url() {
  jq -r '.base_files_url // ""' <<<"$1"
}

download() {
  local url="$1" dest="$2" tmp="${2}.tmp"
  mkdir -p "$(dirname -- "$dest")"
  curl -kfsSL "$url" -o "$tmp"
  mv -f "$tmp" "$dest"
}

download_with_md5() {
  local url="$1" dest="$2" hash="$3" tmp="${2}.tmp"
  mkdir -p "$(dirname -- "$dest")"
  if [[ -n "$hash" && -f "$dest" ]]; then
    if [[ "$(md5sum "$dest" | awk '{print $1}')" == "$hash" ]]; then
      return 1
    fi
  fi
  curl -kfsSL "$url" -o "$tmp"
  if [[ -n "$hash" ]]; then
    local got
    got="$(md5sum "$tmp" | awk '{print $1}')"
    [[ "$got" == "$hash" ]] || { rm -f "$tmp"; return 2; }
  fi
  mv -f "$tmp" "$dest"
  return 0
}

fetch_distribution_manifest() {
  mkdir -p "$(dirname -- "$MANIFEST_FILE")"
  curl -kfsSL "$DIST_URL" -o "$MANIFEST_FILE"
  if [[ "$(file -b --mime-type "$MANIFEST_FILE")" == "application/zip" ]]; then
    unzip -p "$MANIFEST_FILE" '*.json' | head -n 1
  else
    cat "$MANIFEST_FILE"
  fi
}

ensure_layout() {
  local d
  for d in "${ROOT_DIRS[@]}"; do
    mkdir -p "$ROOT/$d"
  done
  mkdir -p "$SCRIPTS_ROOT"
}

sync_root() {
  local manifest="$1" base_url
  base_url="$(manifest_base_url "$manifest")"
  local key name hash rel url
  while IFS=$'\t' read -r key hash; do
    [[ -n "$key" ]] || continue
    rel="${key#|}"
    [[ "$rel" == */* ]] && continue
    name="${rel##*/}"
    local allowed keep=0
    for allowed in "${ROOT_FILES[@]}"; do
      if [[ "$name" == "$allowed" ]]; then
        keep=1
        break
      fi
    done
    [[ "$keep" -eq 1 ]] || continue
    url="${base_url}${key#|}"
    status "$name"
    if download_with_md5 "$url" "$ROOT/$name" "$hash"; then
      done_line "copied: $name"
    else
      done_line "unchanged: $name"
    fi
  done < <(read_manifest "$manifest" | sed -n '/^[^|]/p')
}

sync_linux() {
  local manifest="$1" base_url
  base_url="$(manifest_base_url "$manifest")"
  local key rel hash url
  while IFS=$'\t' read -r key hash; do
    rel="${key#|}"
    [[ "$rel" == linux/* ]] || continue
    url="${base_url}${key#|}"
    status "$rel"
    if download_with_md5 "$url" "$ROOT/$rel" "$hash"; then
      done_line "copied: $rel"
    else
      done_line "unchanged: $rel"
    fi
  done < <(read_manifest "$manifest")
}

sync_cores() {
  local manifest="$1" base_url family key rel name hash best_date best_key best_hash best_url url
  base_url="$(manifest_base_url "$manifest")"
  for family in "${CORE_NAMES[@]}"; do
    best_date=""
    best_key=""
    best_hash=""
    best_url=""
    printf 'core family: %s\n' "$family" >>"$LOG_FILE"
    while IFS=$'\t' read -r key hash; do
      rel="${key#|}"
      [[ "$rel" == _Console/* ]] || continue
      name="${rel##*/}"
      [[ "$name" == ${family}_*.rbf ]] || continue
      printf 'core candidate: %s\n' "$name" >>"$LOG_FILE"
      if [[ "$name" =~ _([0-9]{8})\.rbf$ ]]; then
        if [[ -z "$best_date" || "${BASH_REMATCH[1]}" > "$best_date" ]]; then
          best_date="${BASH_REMATCH[1]}"
          best_key="$key"
          best_hash="$hash"
          best_url="${base_url}${key#|}"
        fi
      fi
    done < <(read_manifest "$manifest")
    [[ -n "$best_url" ]] || continue
    name="${best_key#|}"
    name="${name##*/}"
    status "$name"
    printf 'core match: %s -> %s\n' "$best_key" "$ROOT/$name" >>"$LOG_FILE"
    if download_with_md5 "$best_url" "$ROOT/$name" "$best_hash"; then
      done_line "copied: $name"
    else
      done_line "unchanged: $name"
    fi
  done
}

ensure_game_folders() {
  local folder
  for folder in "${GAME_DIRS[@]}"; do
    mkdir -p "$ROOT/games/$folder"
  done
}

sync_games() {
  local manifest="$1" base_url key rel hash family dest url
  base_url="$(manifest_base_url "$manifest")"
  while IFS=$'\t' read -r key hash; do
    rel="${key#|}"
    [[ "$rel" == games/* ]] || continue
    family="${rel#games/}"
    family="${family%%/*}"
    case "$family" in
      Gameboy|GBA|MegaCD|MegaDrive|N64|NeoGeo|NeoGeo-CD|NeoGeoPocket|NES|PSX|S32X|Saturn|SMS|SNES|TGFX16|TGFX16-CD) ;;
      *) continue ;;
    esac
    url="${base_url}${key#|}"
    dest="$ROOT/$rel"
    status "$rel"
    if download_with_md5 "$url" "$dest" "$hash"; then
      done_line "copied: $rel"
    else
      done_line "unchanged: $rel"
    fi
  done < <(read_manifest "$manifest")
}

sync_bios() {
  local manifest="$1" base_url key rel hash family dest url
  base_url="$(manifest_base_url "$manifest")"
  while IFS=$'\t' read -r key hash; do
    rel="${key#|}"
    [[ "$rel" == games/* ]] || continue
    family="${rel#games/}"
    family="${family%%/*}"
    case "$family" in
      Gameboy|GBA|MegaCD|MegaDrive|N64|NeoGeo|NeoGeo-CD|NeoGeoPocket|NES|PSX|S32X|Saturn|SMS|SNES|TGFX16|TGFX16-CD) ;;
      *) continue ;;
    esac
    url="${base_url}${key#|}"
    dest="$ROOT/$rel"
    status "$rel"
    if [[ -n "$hash" ]]; then
      if download_with_md5 "$url" "$dest" "$hash"; then
        done_line "copied: $rel"
      else
        done_line "unchanged: $rel"
      fi
    elif [[ -f "$dest" ]]; then
      done_line "unchanged: $rel"
    else
      download "$url" "$dest"
      done_line "copied: $rel"
    fi
  done < <(read_manifest "$manifest")
}

sync_scripts() {
  local name url
  for name in "${SCRIPTS_FILES[@]}"; do
    url="$SCRIPTS_URL/$name"
    status "scripts/$name"
    download "$url" "$SCRIPTS_ROOT/$name"
    chmod +x "$SCRIPTS_ROOT/$name"
    done_line "copied: scripts/$name"
  done
}

main() {
  local distribution_manifest bios_manifest
  ensure_layout
  stage distribution
  distribution_manifest="$(fetch_distribution_manifest)"
  stage bios
  bios_manifest="$(curl -kfsSL "$BIOS_URL")"
  stage root
  sync_root "$distribution_manifest"
  stage linux
  sync_linux "$distribution_manifest"
  stage cores
  sync_cores "$distribution_manifest"
  stage games
  ensure_game_folders
  sync_games "$distribution_manifest"
  sync_bios "$bios_manifest"
  stage scripts
  sync_scripts
}

main
