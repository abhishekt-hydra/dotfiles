# Debian/Ubuntu /etc/zsh/zshrc runs its own full compinit before ~/.zshrc;
# .zshrc already runs a cached one. Saves ~25 ms per shell on contabo-ubuntu.
skip_global_compinit=1
