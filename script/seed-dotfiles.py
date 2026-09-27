#!/usr/bin/env python3
"""Seed missing live files, materialize old links, and declare mise tracking.

Existing regular files always win. Backups live outside the tracked tree.
"""
import datetime
import json
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
BACKUP = HOME / ".local/state/dotfiles/backups" / datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")


def backup(path):
    dest = BACKUP / path.relative_to(HOME)
    dest.parent.mkdir(parents=True, exist_ok=True)
    if path.is_dir():
        shutil.copytree(path, dest, symlinks=False)
    else:
        shutil.copy2(path, dest)
    print("Backed up {} -> {}".format(path, dest))


def materialize(path):
    if not path.is_symlink():
        return
    # Read/copy before unlinking; broken links are never silently discarded.
    source = path.resolve(strict=True)
    temp = path.with_name(path.name + ".mise-migration-" + str(os.getpid()))
    if temp.exists() or temp.is_symlink():
        raise RuntimeError("Temporary path already exists: {}".format(temp))
    if source.is_dir():
        shutil.copytree(source, temp, symlinks=True)
    else:
        shutil.copy2(source, temp)
    backup(path)
    path.unlink()
    temp.rename(path)
    print("Materialized {}".format(path))


def prepare_parents(path):
    for parent in reversed(path.parents):
        if parent == HOME or HOME not in parent.parents:
            continue
        materialize(parent)
    path.parent.mkdir(parents=True, exist_ok=True)


def write_config(path, contents):
    prepare_parents(path)
    materialize(path)
    if path.exists():
        if path.read_text() == contents:
            return
        backup(path)
    path.write_text(contents)


def main():
    packages = sys.argv[1:] or ["common"]
    if any(p not in ("common", "macos", "linux", "zellij") for p in packages):
        raise SystemExit("Packages: common macos linux zellij")
    # Preflight all selected links before modifying anything.
    sources = []
    for package in packages:
        base = ROOT / "dotfiles" / package
        if not base.exists():
            continue
        files = sorted(p for p in base.rglob("*") if p.is_file())
        for src in files:
            dst = HOME / src.relative_to(base)
            if dst.is_symlink():
                dst.resolve(strict=True)
            if dst.exists() and not dst.is_file():
                raise RuntimeError("Expected a file: {}".format(dst))
        sources.append((package, base, files))

    for package, base, files in sources:
        entries = ["# Managed by dotfiles/script/link. Live files are the source of truth.", "[dotfiles]"]
        for src in files:
            rel = src.relative_to(base)
            dst = HOME / rel
            prepare_parents(dst)
            materialize(dst)
            if not dst.exists():
                shutil.copy2(src, dst)
                print("Seeded {}".format(dst))
            entries.append('{} = {{ mode = "track" }}'.format(json.dumps("~/" + rel.as_posix())))
        write_config(CONFIG / "mise/conf.d/dotfiles-{}.toml".format(package), "\n".join(entries) + "\n")

    # Stable repo pointer for .zshrc now that it is a regular file. Machine-local.
    write_config(CONFIG / "dotfiles/root", str(ROOT) + "\n")
    history = '''# Managed by dotfiles/script/link. History stays local until an origin is set.
[bootstrap.services.mise-history]
builtin = "history-watch"

[dotfiles]
'''
    for path in sorted(set([CONFIG / "mise/config.toml", CONFIG / "mise/conf.d/dotfiles-history.toml"] + list((CONFIG / "mise/conf.d").glob("dotfiles-*.toml")))):
        history += '{} = {{ mode = "track" }}\n'.format(json.dumps(str(path)))
    write_config(CONFIG / "mise/conf.d/dotfiles-history.toml", history)
    print("Dotfiles prepared; existing regular files preserved.")


if __name__ == "__main__":
    main()
