# ABOUTME: infisical wrapper that injects CF Zero Trust headers from 1Password JIT
# ABOUTME: Headers live only in the infisical subprocess env, never on disk

function infisical --description "Run infisical with CF-Access headers fetched from 1Password on demand"
    if not type -q op
        command infisical $argv
        return $status
    end

    set -l _cf_id (op read --account my.1password.eu 'op://Private/tjrju3c7iio3worbokgufcz6vi/password' 2>/dev/null)
    set -l _cf_secret (op read --account my.1password.eu 'op://Private/2znmqbsjzcefjqcl6mub4n2zau/password' 2>/dev/null)

    if test -z "$_cf_id" -o -z "$_cf_secret"
        command infisical $argv
        return $status
    end

    INFISICAL_CUSTOM_HEADERS="CF-Access-Client-Id=$_cf_id CF-Access-Client-Secret=$_cf_secret" command infisical $argv
end
