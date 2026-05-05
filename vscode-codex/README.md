# Codex CLI VS Code Extension (local)

This minimal extension runs the `codex` CLI with the selected text (or an input prompt) and displays output in a new editor.

How to use (development):

- Open this workspace folder in VS Code.
- Run the Extension Development Host with `F5`.
- Open a file, select text (or leave empty), then run the command palette and choose `Run Codex (CLI)`.

Configuration (in Settings):

- `codex.command` — path to the `codex` executable (default: `codex`).
- `codex.args` — extra arguments to pass (space-separated).
- `codex.useStdin` — send prompt via stdin (default: true).

Packaging & install (optional):

Install `vsce` and then run to create a `.vsix`:

```bash
npm install -g vsce
cd vscode-codex
vsce package
code --install-extension codex-cli-vscode-0.0.1.vsix
```
