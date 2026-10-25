# ABOUTME: Clear screen and display a fortune from habits
# ABOUTME: Autoloaded by fish, bound to Ctrl+L in config.fish

function clear_with_fortune --description "Clear screen and show fortune"
    printf '\033[H\033[2J'
    if type -q fortune; and test -d "$HOME/.local/habits"
        fortune "$HOME/.local/habits"
        echo
    end
end
