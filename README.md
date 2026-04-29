# Patch Codex Extension

Temporary local hotfix for the Codex / ChatGPT IDE extension `stable-metadata` loop in non-git folders.

## What it fixes

When Codex is opened in a folder that is not initialized as a Git repository, some extension builds can enter a tight loop like:

```text
worker_rpc_response_error error={} method=stable-metadata workerId=git
```

Symptoms:

- high renderer / plugin CPU usage
- noisy Codex logs
- laggy chat list or IDE UI

This patch changes the extension so the "not a git repository" case is treated as an empty state instead of an error.

## Files

- `patch-codex-stable-metadata.sh`
- `restore-codex-stable-metadata.sh`

## Supported targets

- Cursor: `~/.cursor/extensions`
- VS Code: `~/.vscode/extensions`

The patch script automatically:

1. finds the newest `openai.chatgpt-*` extension folder
2. creates backups with `.stable-metadata.bak`
3. patches both the extension host bundle and the webview asset

## Apply

From this folder:

```bash
bash patch-codex-stable-metadata.sh
```

If you want to target a specific editor explicitly:

```bash
bash patch-codex-stable-metadata.sh ~/.cursor/extensions
bash patch-codex-stable-metadata.sh ~/.vscode/extensions
```

Then reload the editor window:

- Cursor: `Developer: Reload Window`
- VS Code: `Developer: Reload Window`

## Verify

Open a folder that is not a git repo and then open Codex.

Expected result:

- the UI no longer spins CPU because of `stable-metadata`
- the log spam for `worker_rpc_response_error ... stable-metadata` stops or drops dramatically

## Roll Back

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
