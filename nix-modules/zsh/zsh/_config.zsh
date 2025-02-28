# Configure ZSH
#ZSH_THEME="powerlevel10k"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"
plugins=(git brew docker)
DEFAULT_USER="`whoami`"
# Read the running OS
unameOut="$(uname -s)"

###################################################
# plonk
###################################################
export PATH="$HOME/workspace/src/github.com/winkoz/plonk/bin/:$PATH"

###################################################
# rip-grep
###################################################
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgreprc"

###################################################
# Add all symlinked bin to PATH
###################################################
export PATH="$HOME/.bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

###################################################
# i3blocks contrib
###################################################
export PATH="$HOME/workspace/src/github.com/vivien/i3blocks-contrib/**/:$PATH"

###################################################
# Security scripts
###################################################
#export PATH="$HOME/.security/:$PATH"

# Only run this if on Mac
if [ "${unameOut}" = "Darwin" ]; then
  # Mac, adjust for Python version
  if [ -d "$HOME/Library/Python/3.6/bin/" ] ; then
      PATH="$HOME/Library/Python/3.6/bin/:$PATH"
  fi

  # Configures z plugin
  . `brew --prefix`/etc/profile.d/z.sh

  # BREW CASK
  # Specify your defaults in this environment variable
  export HOMEBREW_CASK_OPTS="--appdir=/Applications"
  export PATH="/opt/homebrew/bin:$PATH"
elif [ "${unameOut}" = "Linux" ]; then
  # Configures z plugin
  . ~/.zsh/z.sh
fi

autoload -U promptinit; promptinit
#prompt pure

###############################################################################
# powerline theme configuration

POWERLINE_RIGHT_A="exit-status-on-fail"
POWERLINE_HIDE_USER_NAME="true"
POWERLINE_HIDE_HOST_NAME="true"
POWERLINE_DETECT_SSH="true"

###############################################################################

# Show menu after multiple tabs
setopt AUTO_MENU

# History settings
# Save x items to the given history file

HISTSIZE=10000
SAVEHIST=10000
HISTFILE=$HOME/.zsh_history

# Append history to the zsh_history file
setopt APPEND_HISTORY

# Write to history after each command
setopt INC_APPEND_HISTORY

# Don't store the history command
setopt HIST_NO_STORE

# Ignore duplicates in zsh history
setopt HIST_IGNORE_ALL_DUPS

# Ignore commands for history that start with a space
setopt HIST_IGNORE_SPACE

# Remove superfluous blanks from each line being added to the history list
setopt HIST_REDUCE_BLANKS

# After !! previous command don't execute, allow editing
setopt HIST_VERIFY

 # Load NVM
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm


export PATH="/usr/local/sbin:$PATH"

# Vi mode
# Based off http://dougblack.io/words/zsh-vi-mode.html
#bindkey -v
bindkey -M vicmd "^V" visual-mode

# ctrl-w removed word backwards
bindkey '^w' backward-kill-word

function zle-line-init zle-keymap-select {
  VIM_PROMPT="%{$fg_bold[green]%} [% VI MODE]%  %{$reset_color%}"
  NORMAL_PROMPT="%{$fg_bold[yellow]%} [% NORMAL]% %{$reset_color%}"
  RPS1="${${KEYMAP/vicmd/$VIM_PROMPT}/(main|viins)/$NORMAL_PROMPT} $EPS1"
  zle reset-prompt
}

zle -N zle-line-init
zle -N zle-keymap-select
export KEYTIMEOUT=1

##############################################################################

# Skip all aliases, in lib files and enabled plugins
zstyle ':omz:*' aliases no
source $ZSH_CUSTOM/../oh-my-zsh.sh

# Auto suggestions & syntax highlight

if [ -z "$_zsh_custom_scripts_loaded" ]; then
  _zsh_custom_scripts_loaded=1
  plugins+=(zsh-autosuggestions zsh-syntax-highlighting)
fi

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#ff00ff,bg=cyan,bold,underline"

##############################################################################

# Load custom config per directory
# Add this to your ~/.zshrc
function chpwd() {
#  if [ -r $PWD/.zsh_config ]; then
#    source $PWD/.zsh_config
#  else
#    source $HOME/.zsh/config.zsh
#  fi
}

##############################################################################
#
# Load credentials ssh keys, etc
#$HOME/.security/*.sh

export PATH="$HOME/.cargo/bin:$PATH"

##############################################################################
#
# Fixes the GPG signing error: Inappropiate ioctl for device
# https://github.com/keybase/keybase-issues/issues/2798
#
##############################################################################

export GPG_TTY=$(tty)

##############################################################################
#
# gh Github CLI autocompletion
#
##############################################################################

#eval "$(gh completion -s zsh)"

##############################################################################
# ATUIN: https://github.com/ellie/atuin
##############################################################################
eval "$(atuin init zsh)"

##############################################################################
# Specifies platform when executing docker
##############################################################################
export PATH="$HOME/.docker/bin:$PATH"

##############################################################################
# pyenv
##############################################################################
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Configure direnv
echo 'eval "$(direnv hook zsh)"'


# vim: ft=muttrc

