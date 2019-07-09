# Export Variables
export ZSH=$HOME/.oh-my-zsh
export PATH=/usr/local/bin:$PATH
export PATH=/usr/bin/gcov:$PATH
export PATH=/usr/local/bin/mergepbx:$PATH
export PATH=$(brew --prefix ruby)/bin:$PATH
export ZSH_PLUGINS_ALIAS_TIPS_EXCLUDES="_ g"

export FPATH=$FPATH:/usr/share/zsh/site-functions/:/usr/share/zsh/5.3/functions/
#:/usr/local/Cellar/zsh/5.4.1/share/zsh/functions/

# Add qt to the path
export PATH="$(brew --prefix qt@5.5)/bin:$PATH"

GOROOT="/usr/local/Cellar/go/1.12.4/libexec"
export GOPATH=~/workspace
export GO111MODULE=on
export PATH=$PATH:/usr/local/bin/go
export PATH=$PATH:$GOPATH/bin
export PATH=$HOME/workspace/src/github.com/soundcloud/ios/scripts/bin:$PATH
export PATH=$PATH:$GOROOT/bin

# Ruby exec path
export PATH=$HOME/.gem/ruby/2.3.0/bin:$PATH

# Python Powerline
export PATH=$HOME/Library/Python/2.7/bin:${PATH}

export LC_ALL"=en_US.UTF-8"
export LANG="en_US.UTF-8"
export EDITOR="vi"
export TERM=xterm-256color
# Disable sending stats to speed up `pod install`
# https://twitter.com/zadr/status/705092258152878080
export COCOAPODS_DISABLE_STATS=1

# HOMEBREW
export HOMEBREW_EDITOR="vi"
# Specify your defaults in this environment variable
#export HOMEBREW_CASK_OPTS="--appdir=/Applications --caskroom=/usr/local/Caskroom"

# DOCKER
export SD_TOOLS_HOME=$HOME/workspace/Tools
export PATH=$PATH:$SD_TOOLS_HOME

# ANDROID
ANDROID_HOME=$HOME/Library/Android/sdk
export ANDROID_HOME=$ANDROID_HOME
export ANDROID_SDK_ROOT=$ANDROID_HOME
export ANDROID_SDK_HOME=$ANDROID_HOME

# vim: ft=muttrc
