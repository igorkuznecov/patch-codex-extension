#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  patch-codex-stable-metadata.sh [extension_root]

Examples:
  patch-codex-stable-metadata.sh
  patch-codex-stable-metadata.sh ~/.cursor/extensions
  patch-codex-stable-metadata.sh ~/.vscode/extensions

What it does:
  - finds the newest openai.chatgpt-* extension directory
  - creates .stable-metadata.bak backups
  - patches the stable-metadata non-git error loop

Supported targets:
  - Cursor: ~/.cursor/extensions
  - VS Code: ~/.vscode/extensions
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

choose_root() {
  if [[ $# -gt 0 ]]; then
    printf '%s\n' "$1"
    return 0
  fi

  if [[ -d "$HOME/.cursor/extensions" ]]; then
    printf '%s\n' "$HOME/.cursor/extensions"
    return 0
  fi

  if [[ -d "$HOME/.vscode/extensions" ]]; then
    printf '%s\n' "$HOME/.vscode/extensions"
    return 0
  fi

  return 1
}

EXTENSIONS_ROOT="$(choose_root "${1:-}")" || {
  echo "Could not detect extensions root. Pass it explicitly."
  usage
  exit 1
}

if [[ ! -d "$EXTENSIONS_ROOT" ]]; then
  echo "Extensions root does not exist: $EXTENSIONS_ROOT"
  exit 1
fi

find_latest_extension_dir() {
  local root="$1"
  local latest_dir
  latest_dir="$(
    find "$root" -maxdepth 1 -type d -name 'openai.chatgpt-*' -print 2>/dev/null \
      | while IFS= read -r dir; do
          stat -f '%m %N' "$dir"
        done \
      | sort -nr \
      | head -n 1 \
      | cut -d' ' -f2-
  )"

  if [[ -z "$latest_dir" ]]; then
    return 1
  fi

  printf '%s\n' "$latest_dir"
}

EXTENSION_DIR="$(find_latest_extension_dir "$EXTENSIONS_ROOT")" || {
  echo "No openai.chatgpt-* extension folder found under: $EXTENSIONS_ROOT"
  exit 1
}

EXTENSION_JS="$EXTENSION_DIR/out/extension.js"
if [[ ! -f "$EXTENSION_JS" ]]; then
  echo "extension.js not found: $EXTENSION_JS"
  exit 1
fi

ASSET_FILE="$(
  find "$EXTENSION_DIR/webview/assets" -maxdepth 1 -type f \
    \( -name 'use-git-stable-metadata-*.js' -o -name 'globe-*.js' \) \
    -print 2>/dev/null \
    | while IFS= read -r file; do
        if grep -q 'method:`stable-metadata`' "$file"; then
          printf '%s\n' "$file"
        fi
      done \
    | head -n 1
)"

if [[ -z "$ASSET_FILE" ]]; then
  echo "Could not find a webview asset that contains stable-metadata."
  exit 1
fi

backup_once() {
  local file="$1"
  local backup="${file}.stable-metadata.bak"
  if [[ ! -f "$backup" ]]; then
    cp "$file" "$backup"
  fi
}

backup_once "$EXTENSION_JS"
backup_once "$ASSET_FILE"

EXTENSION_PATCHED=0
ASSET_PATCHED=0

EXTENSION_SEARCH='if(!o)return r.watchForGitInit===!0?await this.ensureWatchingForGitInit(r.cwd,n):r.watchForGitInit===!1&&this.disposeGitInitWatcher(r.cwd,n),wl("Not a git repository");'
EXTENSION_REPLACE='if(!o)return r.watchForGitInit===!0?await this.ensureWatchingForGitInit(r.cwd,n):r.watchForGitInit===!1&&this.disposeGitInitWatcher(r.cwd,n),ne(null);'

if grep -Fq "$EXTENSION_REPLACE" "$EXTENSION_JS"; then
  :
elif grep -Fq "$EXTENSION_SEARCH" "$EXTENSION_JS"; then
  OLD="$EXTENSION_SEARCH" NEW="$EXTENSION_REPLACE" perl -0pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$EXTENSION_JS"
  EXTENSION_PATCHED=1
else
  echo "Could not find extension.js patch marker. Bundle format may have changed."
  exit 1
fi

ASSET_REPLACE='queryFn:({signal:t})=>e?m(`git`).request({method:`stable-metadata`,params:{cwd:r(String(e)),hostConfig:n,...a?.watchForGitInit==null?{}:{watchForGitInit:a.watchForGitInit}},signal:t}).catch(()=>null):Promise.resolve(null)'
ASSET_SEARCH='queryFn:({signal:t})=>e?m(`git`).request({method:`stable-metadata`,params:{cwd:r(String(e)),hostConfig:n,...a?.watchForGitInit==null?{}:{watchForGitInit:a.watchForGitInit}},signal:t}):Promise.reject(Error(`Missing cwd`))'

if grep -Fq "$ASSET_REPLACE" "$ASSET_FILE"; then
  :
elif grep -Fq "$ASSET_SEARCH" "$ASSET_FILE"; then
  OLD="$ASSET_SEARCH" NEW="$ASSET_REPLACE" perl -0pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$ASSET_FILE"
  ASSET_PATCHED=1
else
  echo "Could not find webview patch marker in: $ASSET_FILE"
  exit 1
fi

if [[ "$EXTENSION_PATCHED" -eq 0 && "$ASSET_PATCHED" -eq 0 ]]; then
  echo "Codex extension already has the stable-metadata patch."
  echo "Extension: $(basename "$EXTENSION_DIR")"
  echo "Extension file: $EXTENSION_JS"
  echo "Asset file: $ASSET_FILE"
  exit 0
fi

echo "Patched Codex extension successfully."
echo "Extension: $(basename "$EXTENSION_DIR")"
echo "Extensions root: $EXTENSIONS_ROOT"
echo "Extension file: $EXTENSION_JS"
echo "Asset file: $ASSET_FILE"
echo "Extension backup: ${EXTENSION_JS}.stable-metadata.bak"
echo "Asset backup: ${ASSET_FILE}.stable-metadata.bak"
echo
echo "Reload Cursor/VS Code window to apply the change."
