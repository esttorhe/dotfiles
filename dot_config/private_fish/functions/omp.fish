# ABOUTME: omp wrapper that loads LITELLM_API_KEY from 1Password the first time omp runs in a shell.
# ABOUTME: Keeps op out of shell startup, so new terminal panes don't each ask for Touch ID.

function omp --description "Run omp with LITELLM_API_KEY loaded from 1Password on first use"
    secrets litellm; or return
    command omp $argv
end
