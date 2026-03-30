# ABOUTME: Delete all local branches matching a given prefix (e.g., 'feat' deletes 'feat/*')
# ABOUTME: Autoloaded by fish when git-clean-branches command is called

function git-clean-branches --description "Delete all local branches matching a prefix"
    if not set -q argv[1]
        echo "Usage: git-clean-branches <prefix>"
        echo "Example: git-clean-branches feat"
        return 1
    end

    set -l prefix $argv[1]

    for branch in (git branch --list "$prefix/*" | string replace -r '^\s*[+*]\s*' '' | string trim)
        git branch -D $branch
    end
end
