# ABOUTME: Sesh-style picker for Rex: choose a Rex session, sesh config entry or zoxide directory with fzf
# ABOUTME: Existing sessions are shown in the Rex app; other picks create a session in that directory first

function rs --description "Switch to or create a Rex session"
    # Each candidate is: kind, display text, target (session id or path), startup command, session label
    set -l candidates
    for row in (rex ls --json | jq -r '.sessions[] | ["rex", "󰆍  " + .label, .session_id, "", .label] | @tsv')
        set -a candidates $row
    end
    for row in (sesh list -c --json | jq -r '.[] | ["config", "  " + .Name, .Path, .StartupCommand, .Name] | @tsv')
        set -a candidates $row
    end
    for dir in (zoxide query -l)
        set -a candidates (printf '%s\t%s\t%s\t%s\t%s' dir "📁  "(string replace -- $HOME '~' $dir) $dir '' (path basename $dir))
    end

    set -l pick (printf '%s\n' $candidates | fzf --delimiter \t --with-nth 2 --no-sort --prompt '⚡  ' --border-label ' rex ')
    test -z "$pick"; and return 0

    set -l fields (string split \t -- $pick)
    set -l kind $fields[1]
    set -l target $fields[3]
    set -l startup $fields[4]
    set -l label $fields[5]

    set -l session_id
    if test "$kind" = rex
        set session_id $target
    else
        # Reuse a session already opened for this entry instead of creating a duplicate
        set session_id (rex ls --json | jq -r --arg l "$label" '.sessions[] | select(.label == $l) | .session_id' | head -n 1)
        if test -z "$session_id"
            set -l command
            if test -n "$startup"
                # Run the startup command, then stay in an interactive shell like sesh does
                set command -- fish -C "$startup"
            end
            set session_id (rex new $label -c $target --json $command | jq -r '.session_id')
        end
    end

    test -n "$session_id"; or return 1
    rex do session.select session_id=$session_id
end
