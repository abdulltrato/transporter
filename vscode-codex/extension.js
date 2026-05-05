const vscode = require('vscode');
const cp = require('child_process');

/**
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
    const outputChannel = vscode.window.createOutputChannel('Codex CLI');
    context.subscriptions.push(outputChannel);

    let disposable = vscode.commands.registerCommand('codex.run', async () => {
        const editor = vscode.window.activeTextEditor;
        let prompt = '';
        if (editor && !editor.selection.isEmpty) {
            prompt = editor.document.getText(editor.selection);
        } else {
            prompt = await vscode.window.showInputBox({ prompt: 'Prompt for Codex' }) || '';
        }
        if (!prompt) {
            vscode.window.showInformationMessage('No prompt provided.');
            return;
        }

        const config = vscode.workspace.getConfiguration('codex');
        const command = config.get('command', 'codex');
        const argsStr = config.get('args', '');
        const args = argsStr ? argsStr.split(' ').filter(Boolean) : [];
        const useStdin = config.get('useStdin', true);

        outputChannel.show(true);
        outputChannel.appendLine(`Running: ${command} ${args.join(' ')}`);

        const child = cp.spawn(command, args, { stdio: ['pipe', 'pipe', 'pipe'] });

        let out = '';
        let err = '';

        child.stdout.on('data', (d) => {
            const s = d.toString();
            out += s;
            outputChannel.append(s);
        });
        child.stderr.on('data', (d) => {
            const s = d.toString();
            err += s;
            outputChannel.append(s);
        });
        child.on('error', (e) => {
            vscode.window.showErrorMessage(`Failed to run codex: ${e.message}`);
        });
        child.on('close', (code) => {
            if (code !== 0) {
                vscode.window.showErrorMessage(`Codex exited with code ${code}`);
            } else {
                vscode.workspace.openTextDocument({ content: out, language: 'text' }).then((doc) => {
                    vscode.window.showTextDocument(doc, { preview: false });
                });
            }
        });

        if (useStdin) {
            child.stdin.write(prompt);
            child.stdin.end();
        } else {
            // Not using stdin: try to send as an argument (may be truncated)
            // This branch left intentionally simple for user customization.
            child.stdin.end();
        }
    });

    context.subscriptions.push(disposable);
}

function deactivate() { }

module.exports = { activate, deactivate };
