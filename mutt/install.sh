#!/bin/bash

SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`
source "$(readlink $SCRIPTPATH/shared_functionality)"
unameOut="$(uname -s)" 

if [ "${unameOut}" = "Darwin" ]; then 
    # Register imap_notifier script to launch at login
    # This scripts registers to listen for all impa accounts
    osascript -e 'tell application "System Events" to make new login item at end with properties {path:"$HOME/.mutt/imap_notifier/register.sh", name:"imap notifier", hidden:false}'
fi
# vim: ft=sh
