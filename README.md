# dotfiles

Cross-platform dotfiles for macOS and Linux.

## Layout

```txt
stow/common/           Shared files linked into $HOME: .zshrc, .tmux.conf, .gitconfig
stow/macos/            macOS-only home files, when needed
stow/linux/            Linux-only home files, when needed
topics/common/**/*.zsh Shared shell modules auto-loaded by .zshrc
topics/macos/**/*.zsh  macOS shell modules auto-loaded on macOS
topics/linux/**/*.zsh  Linux shell modules auto-loaded on Linux
packages/macos/        Homebrew Brewfile for base tools/build prerequisites
packages/linux/        apt/dnf/pacman base tools/build prerequisites
templates/mise/config.toml Global mise tool versions copied to ~/.config/mise/config.toml
os/macos/              Optional macOS defaults scripts
hosts/<hostname>/      Optional machine-specific shell snippets
secrets/               Notes/templates only; do not commit real secrets
```

## New machine

```sh
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh           # installs base packages, links dotfiles, copies mise config, runs mise install
```

Force a profile:

```sh
./install.sh macos
./install.sh linux
./install.sh common --no-packages
```

Mise only:

```sh
./script/mise          # install mise, copy templates/mise/config.toml, run mise install
./script/mise --no-tools
```

Relink only:

```sh
./script/link common
./script/link common macos
./script/link common linux
```

## Tool strategy

- Package manager installs only base CLI tools and build prerequisites.
- Mise installs runtimes/dev tools from `templates/mise/config.toml`: node, python, ruby, go, rust, java, erlang/elixir, neovim, helm, etc.
- Shell startup activates mise through `topics/common/system/mise.zsh`.

## Ideas borrowed from holman/dotfiles

- Topic-oriented shell snippets.
- `path.zsh` loads first, `completion.zsh` loads last.
- `bin/` is added to `$PATH`.
- `bin/dot` refreshes the repo and re-runs setup.
- Private config lives outside git in `~/.localrc` and `~/.gitconfig.local`.

Symlinking is handled by GNU Stow so nested configs like `.config/nvim` are easy later.
