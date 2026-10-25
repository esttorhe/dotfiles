# ABOUTME: Chezmoi abbreviations for fish shell
# ABOUTME: Sourced automatically by fish from conf.d/

abbr -a chema 'chezmoi apply'
abbr -a cmm "chezmoi diff -f git | grep -- ^--- | sed -e 's/^--- a\///' | xargs -r chezmoi merge"
