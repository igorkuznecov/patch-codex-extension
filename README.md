# Codex Extension Stable Metadata Patch

Temporary local hotfix for the Codex / ChatGPT IDE extension `stable-metadata` loop in non-git folders.

This repo exists for people who hit the extension bug where opening Codex in a folder without `.git` causes repeated `stable-metadata` failures, log spam, and high CPU usage in Cursor or VS Code.

## Symptom

Affected extension builds can start spamming lines like:

```text
worker_rpc_response_error error={} method=stable-metadata workerId=git
```

Common effects:

- high renderer or plugin CPU usage
- noisy Codex logs
- laggy chat list or IDE UI
- significantly worse behavior in folders that are not initialized as Git repos

## What this patch does

The patch changes the extension so the "not a git repository" case is treated as an empty state instead of a hard error.

It patches two places:

1. the extension host bundle
2. the webview asset that requests `stable-metadata`

## Quick Start

Run:

```bash
bash patch-codex-stable-metadata.sh
```

Then reload the editor window:

- Cursor: `Developer: Reload Window`
- VS Code: `Developer: Reload Window`

## Files

- `patch-codex-stable-metadata.sh`
- `restore-codex-stable-metadata.sh`
- `LICENSE`

## Supported targets

- Cursor: `~/.cursor/extensions`
- VS Code: `~/.vscode/extensions`

If you want to target a specific editor explicitly:

```bash
bash patch-codex-stable-metadata.sh ~/.cursor/extensions
bash patch-codex-stable-metadata.sh ~/.vscode/extensions
```

## How it works

The patch script automatically:

1. finds all installed `openai.chatgpt-*` extension folders
2. creates backups with `.stable-metadata.bak`
3. patches both the extension host bundle and the webview asset in each matching version

The script is designed to be idempotent. If the extension is already patched, it should report that and exit cleanly.

## Verify

Open a folder that is not a git repo and then open Codex.

Expected result:

- the UI no longer spins CPU because of `stable-metadata`
- log spam for `worker_rpc_response_error ... stable-metadata` stops or drops dramatically
- Codex behaves normally in a non-git folder, or at least much better than before

## Roll Back

Use:

```bash
bash restore-codex-stable-metadata.sh
```

Or explicitly:

```bash
bash restore-codex-stable-metadata.sh ~/.cursor/extensions
bash restore-codex-stable-metadata.sh ~/.vscode/extensions
```

Reload the editor window after restore.

## Notes

- This is a local binary-bundle patch, not an official upstream fix.
- After the extension updates, you may need to run the patch again.
- This patch targets the `stable-metadata` loop only. It does not fix unrelated extension issues.
- If the extension bundle format changes, the patch markers may stop matching and the script may need an update.

## Upstream context

This patch was put together as a practical workaround for the Codex extension issue family around `stable-metadata` loops in non-git folders.

## License

MIT. See [LICENSE](LICENSE).
