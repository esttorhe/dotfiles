# ABOUTME: Read one 1Password secret into a global environment variable, once per shell.
# ABOUTME: Shared by secrets and the tool wrappers so op only runs when a secret is needed.

# Usage: __op_secret VAR ACCOUNT REFERENCE
# Returns 0 when VAR is set afterwards. A value already in the environment is kept,
# so op (and its Touch ID prompt) runs at most once per shell for each secret.
function __op_secret --argument-names var account reference
    set -q $var; and return 0
    if not type -q op
        echo "1Password CLI (op) not found; cannot read $var" >&2
        return 127
    end
    set -l value (op read --account $account $reference 2>/dev/null)
    if test -z "$value"
        echo "could not read $var from 1Password (is it unlocked?)" >&2
        return 1
    end
    set -gx $var "$value"
end
