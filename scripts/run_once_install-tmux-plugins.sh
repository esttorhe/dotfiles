#!/bin/bash
# ABOUTME: Installs TPM (Tmux Plugin Manager) and tmux plugins on first chezmoi apply
# ABOUTME: Ensures catppuccin and other tmux plugins are available after dotfiles setup

TPM_DIR="$HOME/.tmux/plugins/tpm"

if [ ! -d "$TPM_DIR" ]; then
    echo 'Installing TPM (Tmux Plugin Manager)...'
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

echo 'Installing tmux plugins...'
"$TPM_DIR/bin/install_plugins"
