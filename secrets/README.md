# Secrets

Do not commit real secrets here.

Use one of:

- `~/.localrc` for private shell exports
- `~/.gitconfig.local` for identity/work overrides
- 1Password, age, sops, or your password manager for real secrets

## Bitwarden backup via fnox

Install `mise use -g fnox` and `npm install -g @bitwarden/cli`.
The [fnox Bitwarden provider](https://fnox.jdx.dev/providers/bitwarden.html)
reads vault items using the authenticated Bitwarden CLI.

Run these commands in your own terminal; never paste passwords or session tokens
into chat. Use your account's server (US, EU, or self-hosted) before logging in.

```sh
bw login
export BW_SESSION="$(bw unlock --raw)"
./script/secrets-bitwarden backup
./script/secrets-bitwarden verify
# Optional recovery test; refuses to overwrite an existing file:
./script/secrets-bitwarden restore ~/.secrets.restored
```

The helper transfers the whole file as bytes, without interpreting its shell
contents. Each backup creates a new Bitwarden Secure Note. Base64 preserves exact
bytes; Bitwarden provides the vault encryption. Credentials are never passed as
command-line arguments or printed. Child-process output is captured privately,
and errors are suppressed rather than risk displaying secret data. Verification
retrieves the note through fnox and compares bytes internally.

Only the latest item's reference is stored in
`~/.config/dotfiles/fnox-bitwarden.toml` (or `$XDG_CONFIG_HOME/dotfiles/`).
Keep that reference to restore on another machine, or retrieve the item ID from
Bitwarden and recreate the reference. Earlier backups remain in the vault.
The local `~/.secrets` stays unchanged and outside mise history and Git.
This is an explicit backup, not an automatic sync job. Bitwarden Secure Note
size limits apply; a failed upload is reported without displaying its contents.

Afterward, `bw lock` and `unset BW_SESSION` end access from this shell.
