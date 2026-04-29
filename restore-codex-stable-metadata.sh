#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  restore-codex-stable-metadata.sh [extension_root]

Examples:
  restore-codex-stable-metadata.sh
  restore-codex-stable-metadata.sh ~/.cursor/extensions
  restore-codex-stable-metadata.sh ~/.vscode/extensions
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

EXTENSION_DIR="$(
  find "$EXTENSIONS_ROOT" -maxdepth 1 -type d -name 'openai.chatgpt-*' -print 2>/dev/null \
    | while IFS= read -r dir; do
        stat -f '%m %N' "$dir"
      done \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
)"

if [[ -z "$EXTENSION_DIR" ]]; then
  echo "No openai.chatgpt-* extension folder found under: $EXTENSIONS_ROOT"
  exit 1
fi

restore_one() {
  local file="$1"
  local backup="${file}.stable-metadata.bak"
  if [[ -f "$backup" ]]; then
    cp "$backup" "$file"
    echo "Restored: $file"
  fi
}

restore_one "$EXTENSION_DIR/out/extension.js"

find "$EXTENSION_DIR/webview/assets" -maxdepth 1 -type f \
  \( -name 'use-git-stable-metadata-*.js' -o -name 'globe-*.js' \) \
  -print 2>/dev/null \
  | while IFS= read -r file; do
      restore_one "$file"
    done

echo
echo "Reload Cursor/VS Code window to apply the restored files."
