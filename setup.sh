#!/usr/bin/env bash

cd "$(dirname "$0")"
DOTFILES_ROOT=$(pwd -P)

setup_execute_rights () {
  for src in $(find -H "$DOTFILES_ROOT" -maxdepth 2 -name '*.sh' -not -path '*.git*')
  do
    chmod +x $src
    chmod +x "$DOTFILES_ROOT/script/shared_functionality"
    chmod +x "$DOTFILES_ROOT/script/bootstrap"
    chmod +x "$DOTFILES_ROOT/script/install"
  done
}

setup_execute_rights

source "$DOTFILES_ROOT/script/shared_functionality"

info '• bootstrapping'
bash "$DOTFILES_ROOT/script/bootstrap"

info '• installing'
bash "$DOTFILES_ROOT/script/install"
