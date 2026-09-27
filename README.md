# dotfiles

Cross-platform dotfiles for macOS and Linux, managed by **mise bootstrap**
(2026.9.2 or newer). Live files are regular files; mise automatically saves their
history locally, following [Dotfiles That Save Themselves](https://jdx.dev/posts/2026-09-07-dotfiles-that-save-themselves/).

## Layout

```txt
dotfiles/common/       Starter copies for shared live files
dotfiles/macos/        Optional macOS starter files
dotfiles/linux/        Optional Linux starter files
dotfiles/zellij/       Optional Zellij starter files
topics/common/**/*.zsh Shared shell modules auto-loaded by .zshrc
topics/macos/**/*.zsh  macOS shell modules auto-loaded on macOS
topics/linux/**/*.zsh  Linux shell modules auto-loaded on Linux
packages/macos/        Homebrew Brewfile for base tools/build prerequisites
packages/linux/apt.txt Ubuntu/apt base tools/build prerequisites
templates/mise/config.toml Initial global tool versions; existing config is preserved
os/macos/              Optional macOS defaults scripts
hosts/<hostname>/      Optional machine-specific shell snippets
secrets/               Notes/templates only; do not commit real secrets
```

## New machine

```sh
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh           # installs packages/mise, seeds files, enables history, installs tools
```

The migration helper requires Python 3 (installed by the Linux package list;
on macOS, use the Python 3 supplied by developer tools or install it first).
Existing regular files and global mise tool settings are preserved. Old symlinks
are copied into regular files, with standalone backups under
`~/.local/state/dotfiles/backups/`. GNU Stow is not used: the starter copies live
in `dotfiles/`, nothing is symlinked out of the checkout, and the package is not
installed. A machine still holding links into the old `stow/` directory must run
setup from a checkout at commit `bbb97ca` or earlier before pulling this change.

Force a profile:

```sh
./install.sh macos
./install.sh linux
./install.sh common --no-packages
./install.sh macos --with-k8s-tools   # optional: kubefwd, kubectl, grpcurl via mise
```

Mise only:

```sh
./script/mise                    # install mise, seed absent config, install devtools, run mise install
./script/mise --no-tools
./script/mise --no-devtools       # skip devtools like hurl
./script/mise --with-k8s-tools    # optional: mise use -g ubi:txn2/kubefwd kubectl grpcurl
```

SSH/GitHub account setup:

```sh
./script/ssh           # non-destructive: backs up config, creates missing keys, prints public keys
```

This uses the repo's git split:

```txt
github.com-personal -> ~/.ssh/id_ed25519_personal
github.com-hydra    -> ~/.ssh/id_ed25519_hydra
```

## Migrate this machine / manage dotfiles

```sh
./install.sh common --no-packages  # migrate without installing runtimes/base packages
./script/link common             # compatibility name: seed/track, no symlinks
./script/link zellij             # opt in to Zellij files too
mise bootstrap --only dotfiles,services
mise bootstrap dotfiles status
mise bootstrap dotfiles history --path ~/.zshrc
mise bootstrap dotfiles rollback ~/.zshrc --dry-run
```

`script/link` creates global declarations in `~/.config/mise/conf.d/dotfiles-*.toml`,
saves a baseline, and starts the `mise-history` user service through mise bootstrap.
Edit `~/.zshrc`, `~/.tmux.conf`, and other live files normally. Re-running setup
only seeds missing files; it does not overwrite live edits with starter copies.
The starter copies in this checkout are not automatically updated by history.
To change the defaults for future fresh installs, update the corresponding
`dotfiles/` starter explicitly as well.

Shell modules still load from this checkout. `~/.config/dotfiles/root` records its
location; rerun `script/link common` if you move the checkout. Topic files, host
snippets, `~/.secrets`, `~/.localrc`, and `~/.gitconfig.local` are not enrolled in
history. Keep the checkout for the topic modules and helper scripts.

History is local by default. To share it, connect a **separate private history
repository** with `mise bootstrap dotfiles origin set <private-git-url>`.
The existing dotfiles source repository is not automatically used as a history
origin. On another machine, clone this source checkout and install the base
packages/mise first, then restore the history with
`mise bootstrap --from-git <private-git-url>` and rerun `script/link common` to
record that machine's checkout path. Ongoing synchronization needs Git credentials.

## Tool strategy

- Package manager installs only base system tools and build prerequisites.
- Mise installs runtimes/dev CLIs from `templates/mise/config.toml`: node, python, ruby, go, rust, java, erlang/elixir, neovim, helm, eza, gh, ripgrep, lazygit, rclone, tuicr, etc.
- Devtools are installed through mise in a separate script section: `mise use -g hurl@8.0.1`.
- Optional k8s/gRPC CLIs are installed through mise, not Homebrew: `./script/mise --with-k8s-tools` runs `mise use -g ubi:txn2/kubefwd kubectl grpcurl`.
- Shell startup activates mise through `topics/common/system/mise.zsh`.

## Ideas borrowed from holman/dotfiles

- Topic-oriented shell snippets.
- `path.zsh` loads first, `completion.zsh` loads last.
- `bin/` is added to `$PATH`.
- `bin/dot` refreshes the repo and re-runs setup.
- Private config lives outside git in `~/.localrc` and `~/.gitconfig.local`.

To enroll another existing configuration file, run `mise bootstrap dotfiles track <path>`.

## macOS lid-closed caffeinate

`topics/macos/system/caffeinate-lid.zsh`, loaded by `.zshrc`, extends `caffeinate -d`: it prevents
the Mac itself from sleeping while the display-awake hold is active, restores
the former setting after the final concurrent holder exits, and reaps stale
holders at the next prompt. Other `caffeinate` invocations are unchanged.

The first `caffeinate -d` call prompts with `sudo -v`, then refreshes its sudo
timestamp while the hold runs so it can restore the setting on exit. If the
password is declined or authentication fails, it warns and runs standard
`caffeinate` without changing the sleep setting. An optional app at
`~/Library/Application Support/CaffeinateLid/CaffeinateLid.app` receives the
holder-directory path to show a menu-bar indicator. Optional `hotspot` and
`hotspot_leave` shell functions join a hotspot while a lid-safe hold is active
and restore the prior network once the last holder exits.

## Linux caffeinate

The Linux profile seeds `~/.local/bin/caffeinate` and enrolls it in mise
bootstrap tracking. The Bash shim maps the macOS-compatible flags to
`systemd-inhibit`; it uses a direct blocker where permitted and otherwise
prompts for sudo only when lid or sleep inhibition requires it.
