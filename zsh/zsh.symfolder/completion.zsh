# matches case insensitive
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# pasting with tabs doesn't perform completion
zstyle ':completion:*' insert-tab pending

# Ignore compiled files on vi/vim completion
zstyle ':completion:*:*:(v|vim):*:*files' ignored-patterns '*.(a|dylib|so|o|pyc)'

# Don't complete stuff already being used
zstyle ':completion::*:(v|vim|rm|srm):*' ignore-line true

# Cache to increase speed
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zsh/tmp/cache"

# Explicitly write the type of what autocomplete has found / was looking for
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:warnings' format 'No matches for: %d'

##############################################################################
#     ____      ____
#    / __/___  / __/
#   / /_/_  / / /_
#  / __/ / /_/ __/
# /_/   /___/_/-completion.zsh
#
# - $FZF_TMUX               (default: 1)
# - $FZF_TMUX_HEIGHT        (default: '40%')
# - $FZF_COMPLETION_TRIGGER (default: '**')
# - $FZF_COMPLETION_OPTS    (default: empty)
##############################################################################

# To use custom commands instead of find, override _fzf_compgen_{path,dir}
if ! declare -f _fzf_compgen_path > /dev/null; then
  _fzf_compgen_path() {
    echo "$1"
    command find -L "$1" \
      -name .git -prune -o -name .svn -prune -o \( -type d -o -type f -o -type l \) \
      -a -not -path "$1" -print 2> /dev/null | sed 's@^\./@@'
  }
fi

if ! declare -f _fzf_compgen_dir > /dev/null; then
  _fzf_compgen_dir() {
    command find -L "$1" \
      -name .git -prune -o -name .svn -prune -o -type d \
      -a -not -path "$1" -print 2> /dev/null | sed 's@^\./@@'
  }
fi

###########################################################

__fzf_generic_path_completion() {
  local base lbuf compgen fzf_opts suffix tail fzf dir leftover matches
  # (Q) flag removes a quoting level: "foo\ bar" => "foo bar"
  base=${(Q)1}
  lbuf=$2
  compgen=$3
  fzf_opts=$4
  suffix=$5
  tail=$6
  [ ${FZF_TMUX:-1} -eq 1 ] && fzf="fzf-tmux -d ${FZF_TMUX_HEIGHT:-40%}" || fzf="fzf"

  setopt localoptions nonomatch
  dir="$base"
  while [ 1 ]; do
    if [ -z "$dir" -o -d ${~dir} ]; then
      leftover=${base/#"$dir"}
      leftover=${leftover/#\/}
      [ -z "$dir" ] && dir='.'
      [ "$dir" != "/" ] && dir="${dir/%\//}"
      dir=${~dir}
      matches=$(eval "$compgen $(printf %q "$dir")" | ${=fzf} ${=FZF_COMPLETION_OPTS} ${=fzf_opts} -q "$leftover" | while read item; do
        echo -n "${(q)item}$suffix "
      done)
      matches=${matches% }
      if [ -n "$matches" ]; then
        LBUFFER="$lbuf$matches$tail"
      fi
      zle redisplay
      typeset -f zle-line-init >/dev/null && zle zle-line-init
      break
    fi
    dir=$(dirname "$dir")
    dir=${dir%/}/
  done
}

_fzf_path_completion() {
  __fzf_generic_path_completion "$1" "$2" _fzf_compgen_path \
    "-m" "" " "
}

_fzf_dir_completion() {
  __fzf_generic_path_completion "$1" "$2" _fzf_compgen_dir \
    "" "/" ""
}

_fzf_feed_fifo() (
  command rm -f "$1"
  mkfifo "$1"
  cat <&0 > "$1" &
)

_fzf_complete() {
  local fifo fzf_opts lbuf fzf matches post
  fifo="${TMPDIR:-/tmp}/fzf-complete-fifo-$$"
  fzf_opts=$1
  lbuf=$2
  post="${funcstack[2]}_post"
  type $post > /dev/null 2>&1 || post=cat

  [ ${FZF_TMUX:-1} -eq 1 ] && fzf="fzf-tmux -d ${FZF_TMUX_HEIGHT:-40%}" || fzf="fzf"

  _fzf_feed_fifo "$fifo"
  matches=$(cat "$fifo" | ${=fzf} ${=FZF_COMPLETION_OPTS} ${=fzf_opts} -q "${(Q)prefix}" | $post | tr '\n' ' ')
  if [ -n "$matches" ]; then
    LBUFFER="$lbuf$matches"
  fi
  zle redisplay
  typeset -f zle-line-init >/dev/null && zle zle-line-init
  command rm -f "$fifo"
}

_fzf_complete_telnet() {
  _fzf_complete '+m' "$@" < <(
    command grep -v '^\s*\(#\|$\)' /etc/hosts | command grep -Fv '0.0.0.0' |
        awk '{if (length($2) > 0) {print $2}}' | sort -u
  )
}

_fzf_complete_ssh() {
  _fzf_complete '+m' "$@" < <(
    cat <(cat ~/.ssh/config /etc/ssh/ssh_config 2> /dev/null | command grep -i '^host' | command grep -v '*') \
        <(command grep -oE '^[^ ]+' ~/.ssh/known_hosts | tr ',' '\n' | awk '{ print $1 " " $1 }') \
        <(command grep -v '^\s*\(#\|$\)' /etc/hosts | command grep -Fv '0.0.0.0') |
        awk '{if (length($2) > 0) {print $2}}' | sort -u
  )
}

_fzf_complete_export() {
  _fzf_complete '-m' "$@" < <(
    declare -xp | sed 's/=.*//' | sed 's/.* //'
  )
}

_fzf_complete_unset() {
  _fzf_complete '-m' "$@" < <(
    declare -xp | sed 's/=.*//' | sed 's/.* //'
  )
}

_fzf_complete_unalias() {
  _fzf_complete '+m' "$@" < <(
    alias | sed 's/=.*//'
  )
}

fzf-completion() {
  local tokens cmd prefix trigger tail fzf matches lbuf d_cmds
  setopt localoptions noshwordsplit noksh_arrays

  # http://zsh.sourceforge.net/FAQ/zshfaq03.html
  # http://zsh.sourceforge.net/Doc/Release/Expansion.html#Parameter-Expansion-Flags
  tokens=(${(z)LBUFFER})
  if [ ${#tokens} -lt 1 ]; then
    zle ${fzf_default_completion:-expand-or-complete}
    return
  fi

  cmd=${tokens[1]}

  # Explicitly allow for empty trigger.
  trigger=${FZF_COMPLETION_TRIGGER-'**'}
  [ -z "$trigger" -a ${LBUFFER[-1]} = ' ' ] && tokens+=("")

  tail=${LBUFFER:$(( ${#LBUFFER} - ${#trigger} ))}
  # Kill completion (do not require trigger sequence)
  if [ $cmd = kill -a ${LBUFFER[-1]} = ' ' ]; then
    [ ${FZF_TMUX:-1} -eq 1 ] && fzf="fzf-tmux -d ${FZF_TMUX_HEIGHT:-40%}" || fzf="fzf"
    matches=$(ps -ef | sed 1d | ${=fzf} ${=FZF_COMPLETION_OPTS} -m | awk '{print $2}' | tr '\n' ' ')
    if [ -n "$matches" ]; then
      LBUFFER="$LBUFFER$matches"
    fi
    zle redisplay
    typeset -f zle-line-init >/dev/null && zle zle-line-init
  # Trigger sequence given
  elif [ ${#tokens} -gt 1 -a "$tail" = "$trigger" ]; then
    d_cmds=(${=FZF_COMPLETION_DIR_COMMANDS:-cd pushd rmdir})

    [ -z "$trigger"      ] && prefix=${tokens[-1]} || prefix=${tokens[-1]:0:-${#trigger}}
    [ -z "${tokens[-1]}" ] && lbuf=$LBUFFER        || lbuf=${LBUFFER:0:-${#tokens[-1]}}

    if eval "type _fzf_complete_${cmd} > /dev/null"; then
      eval "prefix=\"$prefix\" _fzf_complete_${cmd} \"$lbuf\""
    elif [ ${d_cmds[(i)$cmd]} -le ${#d_cmds} ]; then
      _fzf_dir_completion "$prefix" "$lbuf"
    else
      _fzf_path_completion "$prefix" "$lbuf"
    fi
  # Fall back to default completion
  else
    zle ${fzf_default_completion:-expand-or-complete}
  fi
}

[ -z "$fzf_default_completion" ] && {
  binding=$(bindkey '^I')
  [[ $binding =~ 'undefined-key' ]] || fzf_default_completion=$binding[(w)2]
  unset binding
}

zle     -N   fzf-completion
bindkey '^I' fzf-completion

##############################################################################

run(){
    start=$(date +%s)
    eval $@;
    [ $(($(date +%s) - start)) -le 10 ] || ntfy -b telegram send "Notification Long running command \"$(echo $@)\" took $(($(date +%s) - start)) seconds to finish"
}

##############################################################################
# man pages in a nicer presentation

function help() {
  man -t $1 | open -f -a /System/Applications/Preview.app
}

##############################################################################
#
# Autocompletion for gh Github CLI
#

#compdef _gh gh


function _gh {
  local -a commands

  _arguments -C \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:' \
    '--version[Show gh version]' \
    "1: :->cmnds" \
    "*::arg:->args"

  case $state in
  cmnds)
    commands=(
      "completion:Generate shell completion scripts"
      "config:Set and get gh settings"
      "credits:View project's credits"
      "gist:Create gists"
      "help:Help about any command"
      "issue:Create and view issues"
      "pr:Create, view, and checkout pull requests"
      "repo:Create, clone, fork, and view repositories"
    )
    _describe "command" commands
    ;;
  esac

  case "$words[1]" in
  completion)
    _gh_completion
    ;;
  config)
    _gh_config
    ;;
  credits)
    _gh_credits
    ;;
  gist)
    _gh_gist
    ;;
  help)
    _gh_help
    ;;
  issue)
    _gh_issue
    ;;
  pr)
    _gh_pr
    ;;
  repo)
    _gh_repo
    ;;
  esac
}

function _gh_completion {
  _arguments \
    '(-s --shell)'{-s,--shell}'[Shell type: {bash|zsh|fish|powershell}]:' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}


function _gh_config {
  local -a commands

  _arguments -C \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:' \
    "1: :->cmnds" \
    "*::arg:->args"

  case $state in
  cmnds)
    commands=(
      "get:Prints the value of a given configuration key"
      "set:Updates configuration with the value of a given key"
    )
    _describe "command" commands
    ;;
  esac

  case "$words[1]" in
  get)
    _gh_config_get
    ;;
  set)
    _gh_config_set
    ;;
  esac
}

function _gh_config_get {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_config_set {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_credits {
  _arguments \
    '(-s --static)'{-s,--static}'[Print a static version of the credits]' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}


function _gh_gist {
  local -a commands

  _arguments -C \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:' \
    "1: :->cmnds" \
    "*::arg:->args"

  case $state in
  cmnds)
    commands=(
      "create:Create a new gist"
    )
    _describe "command" commands
    ;;
  esac

  case "$words[1]" in
  create)
    _gh_gist_create
    ;;
  esac
}

function _gh_gist_create {
  _arguments \
    '(-d --desc)'{-d,--desc}'[A description for this gist]:' \
    '(-p --public)'{-p,--public}'[When true, the gist will be public and available for anyone to see (default: private)]' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_help {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}


function _gh_issue {
  local -a commands

  _arguments -C \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:' \
    "1: :->cmnds" \
    "*::arg:->args"

  case $state in
  cmnds)
    commands=(
      "close:Close issue"
      "create:Create a new issue"
      "list:List and filter issues in this repository"
      "reopen:Reopen issue"
      "status:Show status of relevant issues"
      "view:View an issue"
    )
    _describe "command" commands
    ;;
  esac

  case "$words[1]" in
  close)
    _gh_issue_close
    ;;
  create)
    _gh_issue_create
    ;;
  list)
    _gh_issue_list
    ;;
  reopen)
    _gh_issue_reopen
    ;;
  status)
    _gh_issue_status
    ;;
  view)
    _gh_issue_view
    ;;
  esac
}

function _gh_issue_close {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_issue_create {
  _arguments \
    '(*-a *--assignee)'{\*-a,\*--assignee}'[Assign a person by their `login`]:' \
    '(-b --body)'{-b,--body}'[Supply a body. Will prompt for one otherwise.]:' \
    '(*-l *--label)'{\*-l,\*--label}'[Add a label by `name`]:' \
    '(-m --milestone)'{-m,--milestone}'[Add the issue to a milestone by `name`]:' \
    '(*-p *--project)'{\*-p,\*--project}'[Add the issue to a project by `name`]:' \
    '(-t --title)'{-t,--title}'[Supply a title. Will prompt for one otherwise.]:' \
    '(-w --web)'{-w,--web}'[Open the browser to create an issue]' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_issue_list {
  _arguments \
    '(-a --assignee)'{-a,--assignee}'[Filter by assignee]:' \
    '(-A --author)'{-A,--author}'[Filter by author]:' \
    '(*-l *--label)'{\*-l,\*--label}'[Filter by label]:' \
    '(-L --limit)'{-L,--limit}'[Maximum number of issues to fetch]:' \
    '(-s --state)'{-s,--state}'[Filter by state: {open|closed|all}]:' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_issue_reopen {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_issue_status {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_issue_view {
  _arguments \
    '(-w --web)'{-w,--web}'[Open an issue in the browser]' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}


function _gh_pr {
  local -a commands

  _arguments -C \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:' \
    "1: :->cmnds" \
    "*::arg:->args"

  case $state in
  cmnds)
    commands=(
      "checkout:Check out a pull request in Git"
      "close:Close a pull request"
      "create:Create a pull request"
      "diff:View a pull request's changes."
      "list:List and filter pull requests in this repository"
      "merge:Merge a pull request"
      "ready:Make a pull request as ready for review"
      "reopen:Reopen a pull request"
      "review:Add a review to a pull request."
      "status:Show status of relevant pull requests"
      "view:View a pull request"
    )
    _describe "command" commands
    ;;
  esac

  case "$words[1]" in
  checkout)
    _gh_pr_checkout
    ;;
  close)
    _gh_pr_close
    ;;
  create)
    _gh_pr_create
    ;;
  diff)
    _gh_pr_diff
    ;;
  list)
    _gh_pr_list
    ;;
  merge)
    _gh_pr_merge
    ;;
  ready)
    _gh_pr_ready
    ;;
  reopen)
    _gh_pr_reopen
    ;;
  review)
    _gh_pr_review
    ;;
  status)
    _gh_pr_status
    ;;
  view)
    _gh_pr_view
    ;;
  esac
}

function _gh_pr_checkout {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_pr_close {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_pr_create {
  _arguments \
    '(*-a *--assignee)'{\*-a,\*--assignee}'[Assign a person by their `login`]:' \
    '(-B --base)'{-B,--base}'[The branch into which you want your code merged]:' \
    '(-b --body)'{-b,--body}'[Supply a body. Will prompt for one otherwise.]:' \
    '(-d --draft)'{-d,--draft}'[Mark pull request as a draft]' \
    '(-f --fill)'{-f,--fill}'[Do not prompt for title/body and just use commit info]' \
    '(*-l *--label)'{\*-l,\*--label}'[Add a label by `name`]:' \
    '(-m --milestone)'{-m,--milestone}'[Add the pull request to a milestone by `name`]:' \
    '(*-p *--project)'{\*-p,\*--project}'[Add the pull request to a project by `name`]:' \
    '(*-r *--reviewer)'{\*-r,\*--reviewer}'[Request a review from someone by their `login`]:' \
    '(-t --title)'{-t,--title}'[Supply a title. Will prompt for one otherwise.]:' \
    '(-w --web)'{-w,--web}'[Open the web browser to create a pull request]' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_pr_diff {
  _arguments \
    '(-c --color)'{-c,--color}'[Whether or not to output color: {always|never|auto}]:' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_pr_list {
  _arguments \
    '(-a --assignee)'{-a,--assignee}'[Filter by assignee]:' \
    '(-B --base)'{-B,--base}'[Filter by base branch]:' \
    '(*-l *--label)'{\*-l,\*--label}'[Filter by label]:' \
    '(-L --limit)'{-L,--limit}'[Maximum number of items to fetch]:' \
    '(-s --state)'{-s,--state}'[Filter by state: {open|closed|merged|all}]:' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_pr_merge {
  _arguments \
    '(-d --delete-branch)'{-d,--delete-branch}'[Delete the local and remote branch after merge]' \
    '(-m --merge)'{-m,--merge}'[Merge the commits with the base branch]' \
    '(-r --rebase)'{-r,--rebase}'[Rebase the commits onto the base branch]' \
    '(-s --squash)'{-s,--squash}'[Squash the commits into one commit and merge it into the base branch]' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_pr_ready {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_pr_reopen {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_pr_review {
  _arguments \
    '(-a --approve)'{-a,--approve}'[Approve pull request]' \
    '(-b --body)'{-b,--body}'[Specify the body of a review]:' \
    '(-c --comment)'{-c,--comment}'[Comment on a pull request]' \
    '(-r --request-changes)'{-r,--request-changes}'[Request changes on a pull request]' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_pr_status {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_pr_view {
  _arguments \
    '(-w --web)'{-w,--web}'[Open a pull request in the browser]' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}


function _gh_repo {
  local -a commands

  _arguments -C \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:' \
    "1: :->cmnds" \
    "*::arg:->args"

  case $state in
  cmnds)
    commands=(
      "clone:Clone a repository locally"
      "create:Create a new repository"
      "fork:Create a fork of a repository"
      "view:View a repository"
    )
    _describe "command" commands
    ;;
  esac

  case "$words[1]" in
  clone)
    _gh_repo_clone
    ;;
  create)
    _gh_repo_create
    ;;
  fork)
    _gh_repo_fork
    ;;
  view)
    _gh_repo_view
    ;;
  esac
}

function _gh_repo_clone {
  _arguments \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_repo_create {
  _arguments \
    '(-d --description)'{-d,--description}'[Description of repository]:' \
    '--enable-issues[Enable issues in the new repository]' \
    '--enable-wiki[Enable wiki in the new repository]' \
    '(-h --homepage)'{-h,--homepage}'[Repository home page URL]:' \
    '--public[Make the new repository public (default: private)]' \
    '(-t --team)'{-t,--team}'[The name of the organization team to be granted access]:' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_repo_fork {
  _arguments \
    '--clone[Clone fork: {true|false|prompt}]' \
    '--remote[Add remote for fork: {true|false|prompt}]' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

function _gh_repo_view {
  _arguments \
    '(-w --web)'{-w,--web}'[Open a repository in the browser]' \
    '--help[Show help for command]' \
    '(-R --repo)'{-R,--repo}'[Select another repository using the `OWNER/REPO` format]:'
}

######################################################################################
#
# Completions for asdf
#
######################################################################################

if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH

  autoload -Uz compinit
  compinit
fi

# vim: ft=muttrc
