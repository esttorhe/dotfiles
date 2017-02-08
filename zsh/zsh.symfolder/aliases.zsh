# Aliases
alias rm="trash"
alias be="bundle exec"
alias bef="be fastlane"
alias buu="brew update && brew upgrade -all && brew cleanup && brew cask cleanup"
alias gu="gem update --no-document && gem cleanup"
eval "$(hub alias -s)"
alias la='ls -lan'
alias xc='open *.xcworkspace'

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

# vim: ft=muttrc
