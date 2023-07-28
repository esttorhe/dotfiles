# Export Variables
#export ZSH=$HOME/.oh-my-zsh
export PATH=/usr/local/bin:$PATH
export PATH=/usr/bin/gcov:$PATH
export PATH=/usr/local/bin/mergepbx:$PATH
unameOut="$(uname -s)"
if [ "${unameOut}" = "Darwin" ]; then
    export PATH=$(brew --prefix ruby)/bin:$PATH
    # Add qt to the path
    export PATH="$(brew --prefix qt@5)/bin:$PATH"

    # HOMEBREW
    export HOMEBREW_EDITOR="vi"
fi

export ZSH_PLUGINS_ALIAS_TIPS_EXCLUDES="_ g"

export FPATH=$FPATH:/usr/share/zsh/site-functions/:/usr/share/zsh/5.3/functions/
#:/usr/local/Cellar/zsh/5.4.1/share/zsh/functions/

GOROOT="/usr/local/Cellar/go/1.12.4/libexec"
export GOPATH=~/workspace
export GO111MODULE=on
export PATH=$PATH:/usr/local/bin/go
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$GOROOT/bin

# Python Powerline
export PATH=$HOME/Library/Python/2.7/bin:${PATH}

export LC_ALL"=en_US.UTF-8"
export LANG="en_US.UTF-8"
export EDITOR="vi"
export TERM=xterm-256color

# DOCKER
export CRUN_NFS=1

# vim: ft=muttrc
