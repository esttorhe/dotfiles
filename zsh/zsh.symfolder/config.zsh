# Configure ZSH
#ZSH_THEME="pygmalion"
ZSH_THEME="agnoster"
#ZSH_THEME="powerline"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"
plugins=(git brew xcode)
DEFAULT_USER="`whoami`"
export FPATH=$FPATH:/usr/share/zsh/site-functions:/usr/local/Cellar/zsh/5.4.1/share/zsh/functions/

###############################################################################
# powerline theme configuration

POWERLINE_RIGHT_A="exit-status-on-fail"
POWERLINE_HIDE_USER_NAME="true"
POWERLINE_HIDE_HOST_NAME="true"
#POWERLINE_PATH="short"
POWERLINE_DETECT_SSH="true"

###############################################################################

# Configure z plugin
. `brew --prefix`/etc/profile.d/z.sh

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

# Source nvm
. $HOME/.nvm/nvm.sh
export NVM_DIR="$HOME/.nvm"
. "$(brew --prefix nvm)/nvm.sh"

# BREW CASK
# Specify your defaults in this environment variable
export HOMEBREW_CASK_OPTS="--appdir=/Applications --caskroom=/usr/local/Caskroom"

# Vi mode
# Based off http://dougblack.io/words/zsh-vi-mode.html
bindkey -v

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

function xcode() {
  _z $1
  xc
}

source $ZSH/oh-my-zsh.sh
# Auto suggestions
source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# Syntax hightlight
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# vim: ft=muttrc
