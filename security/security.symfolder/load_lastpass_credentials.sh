#!/bin/sh

creds=""
loaded="$(ssh-add -l)"

lpass login $LASTPASS_LOGIN
eval $(op signin $OP_TEAM)

for key in $(ls $HOME/.ssh/*_rsa); do
  if echo "$loaded" | grep -q "$key"; then
    continue
  fi

  if [ -z "$creds" ]; then
    creds="$(lpass show --notes ssh)"
    op_creds="$(op get item ssh)"
    creds="$creds\n$op_creds"
    $op_creds"
  fi

  pw=$(echo "$creds" | grep "${key#$HOME/}" | cut -d\  -f2)
  if [ -n "$pw" ]; then
    ssh-add-p "$key" "$pw"
  else
    ssh-add "$key"
  fi
done
