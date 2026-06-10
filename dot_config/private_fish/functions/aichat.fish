# ABOUTME: aichat wrapper that injects OPENAI_API_KEY from 1Password JIT
# ABOUTME: API key lives only in the aichat subprocess env, never on disk

function aichat --description "Run aichat with OPENAI_API_KEY fetched from 1Password on demand"
    if not type -q op
        echo "aichat: 1Password CLI (op) not found; cannot fetch OPENAI_API_KEY" >&2
        return 127
    end

    set -l _key (op read --account my.1password.eu 'op://Private/rt2jbulnr445w424bjmxkypf3y/password' 2>/dev/null)

    if test -z "$_key"
        echo "aichat: could not fetch OPENAI_API_KEY from 1Password (is it unlocked?)" >&2
        return 1
    end

    OPENAI_API_KEY="$_key" command aichat $argv
end
