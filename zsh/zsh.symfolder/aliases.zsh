# Aliases
alias rm="trash"
alias be="bundle exec"
alias bef="be fastlane"
alias buu="brew update && brew upgrade -all && brew cleanup -s"
alias gu="gem update --no-document && gem cleanup"
eval "$(hub alias -s)"
#alias la='ls -lan'
alias la="exa -abghHliS --git"
alias xc='open *.xcworkspace'

# Look up for unreachable commits || Use it with --grep=<something useful>
alias gitlost="git fsck --unreachable | grep commit | cut -d ' ' -f3 | xargs git log --merges --no-walk --grep="

alias swiftc='xcrun -sdk macosx swiftc'

alias zsource="source $HOME/.zshrc"
alias imaps="imapu; imapr"

alias make=gmake

eval $(thefuck --alias)

alias flushcache='sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder'

function brew.info {
  grep desc $(brew --prefix)/Library/Formula/*.rb | perl -ne 'm{^.*/(.*?)\.rb.*?\"(.*)"$} and print "$1|$2\n"' | column -t -s '|' | fzf --reverse
}

alias dlog='idevicesyslog | grep'

alias dls='docker ps'
alias drm='docker rm -f'

# Bundle install
alias bip='bundle install --path=./vendor/bundle'

# Remove all .orig files
alias rmorig='rm -rf **/**.orig'

# SoundCloud knife

alias scknife='crun -i -o "-e USER=${USER} -v ${HOME}/.chef:${HOME}/.chef" system:latest -- bash'

# vim: ft=muttrc
