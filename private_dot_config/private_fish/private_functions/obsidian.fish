# ABOUTME: Launch Obsidian with 1Password SSH agent on macOS
# ABOUTME: Autoloaded by fish when obsidian command is called

function obsidian --description "Launch Obsidian with 1Password SSH agent"
    SSH_AUTH_SOCK=~/.1password/agent.sock ~/Applications/Obsidian.app/Contents/MacOS/Obsidian &
end
