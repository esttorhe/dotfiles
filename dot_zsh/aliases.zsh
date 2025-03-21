##################################################################
# Aliases
##################################################################
# Read the running OS
unameOut="$(uname -s)"

alias rm="trash"
alias vim="nvim"
alias vi="nvim"

if [ "${unameOut}" = "Darwin" ]; then
  alias obsidian='SSH_AUTH_SOCK=~/.1password/agent.sock ~/Applications/Obsidian.app/Contents/MacOS/Obsidian &'
  eval $(thefuck --alias)
  alias flushcache='sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder'
  alias update="brew update && brew upgrade && brew upgrade --cask && brew cleanup -s && mas upgrade"
  # GoLand
  alias goland="$HOME/.jetbrains/goland"

  function brew.info {
    grep desc $(brew --prefix)/Library/Formula/*.rb | perl -ne 'm{^.*/(.*?)\.rb.*?\"(.*)"$} and print "$1|$2\n"' | column -t -s '|' | fzf --reverse
  }
else
  alias update="sudo apt update && sudo apt upgrade --fix-missing --fix-broken && sudo apt autoclean && sudo apt autoremove && sudo snap refresh && sudo restic self-update"
fi

alias be="bundle exec"
alias gu="gem update --no-document && gem cleanup"
alias la="eza -abghHliS --git --icons"

# Look up for unreachable commits || Use it with --grep=<something useful>
alias gitlost="git fsck --unreachable | grep commit | cut -d ' ' -f3 | xargs git log --merges --no-walk --grep="

alias zsource="source $HOME/.zshrc | tte slide --merge"
alias imaps="imapu; imapr"

function mount_remote_file(){
  sudo sshfs -o allow_other,defer_permissions estebantorres@shell:$1 $2
}

alias dlog='idevicesyslog | grep'

alias dls='docker ps'
alias drm='docker rm -f'
alias dockrun='docker run -v `pwd`:/root/`printf '%q\n' "${PWD##*/}"` -it'

# Bundle install
alias bip='bundle install --path=./vendor/bundle'

# Remove all .orig files
alias rmorig='rm -rf **/**.orig'

# Run specific go test
alias gotr='go test -run'

# sbr - checkout git branch (including remote branches), sorted by most recent commit, limit 30 last branches
sbr() {
  local branches branch
  branches=$(git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format="%(refname:short)") &&
  branch=$(echo "$branches" |
           fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
  git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

# Alias for transfer.sh
transfer() { 
    # check arguments
    if [ $# -eq 0 ]; then 
        echo "No arguments specified." >&2
        echo "Usage:" >&2
        echo "  transfer <file|directory>" >&2
        echo "  ... | transfer <file_name>" >&2
        return 1
    fi
    
    # upload stdin or file
    if tty -s; then 
        file="$1"
        if [ ! -e "$file" ]; then
            echo "$file: No such file or directory" >&2
            return 1
        fi
        
        file_name=$(basename "$file" | sed -e 's/[^a-zA-Z0-9._-]/-/g') 
        
        # upload file or directory
        if [ -d "$file" ]; then
            # transfer directory
            file_name="$file_name.zip" 
            (cd "$file" && zip -r -q - .) | curl --progress-bar --upload-file "-" "https://transfer.sh/$file_name" | tee /dev/null
        else 
            # transfer file
            cat "$file" | curl --progress-bar --upload-file "-" "https://transfer.sh/$file_name" | tee /dev/null
        fi
    else 
        # transfer pipe
        file_name=$1
        curl --progress-bar --upload-file "-" "https://transfer.sh/$file_name" | tee /dev/null
    fi
}

# pbcopy
if [ "${unameOut}" = "Linux" ]; then
	alias pbcopy='xclip -selection clipboard'
fi

##########################################################################
# ZenJob
##########################################################################
alias activate-toolbelt='source ~/toolbelt/bin/activate'

alias cat='bat'

alias lg='lazygit'

##########################################################################
# Git
##########################################################################
alias gst="git status"
alias ga="git add"
alias gb="git branch"
alias gp="git push"
alias gcmsg="git commit -m"
alias grbi="git rebase -i"
alias grbc="git rebase --continue"
alias grba="git rebase --abort"
alias gc="git commit"
alias gd="git diff"
alias gco="git checkout"
alias gc="git commit --amend"


# vim: ft=muttrc
