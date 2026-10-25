# ABOUTME: gh wrapper that strips GITHUB_TOKEN/GH_TOKEN so gh uses keyring auth
# ABOUTME: GITHUB_TOKEN is kept globally for other tools that expect it

function gh --description "Run gh with GITHUB_TOKEN/GH_TOKEN unset so it falls back to keyring auth"
    env -u GITHUB_TOKEN -u GH_TOKEN gh $argv
end
