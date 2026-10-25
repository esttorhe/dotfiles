# ABOUTME: Regenerate keybinding habits fortune file and reload config
# ABOUTME: Autoloaded by fish when make-commands-habits command is called

function make-commands-habits --description "Regenerate keybinding habits and reload fish config"
    $HOME/scripts/keybinding-fortune-generator
    source ~/.config/fish/config.fish
end
