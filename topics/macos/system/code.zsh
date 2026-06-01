# Make the VS Code `code` command available when installed as a cask.
typeset -U path PATH
_vscode_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
[[ -d "$_vscode_bin" ]] && path=("$_vscode_bin" $path)
unset _vscode_bin
export PATH
