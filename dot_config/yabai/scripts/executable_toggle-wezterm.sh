#!/bin/bash
# ABOUTME: ghostty toggle - debug and fix process detection
# ABOUTME: Find the actual process name and make it work

# Debug: show what processes are actually running
echo "DEBUG: Looking for ghostty-like processes:"
ps aux | grep -i ghostty | grep -v grep || echo "No ghostty processes found"

# Try different possible ghostty process names
for app_name in "ghostty" "ghosttyterm" "ghosttyterm-gui"; do
  echo "DEBUG: Checking process name: $app_name"

  if pgrep -f "$app_name" >/dev/null; then
    echo "DEBUG: Found running process: $app_name"

    # Check if visible in System Events
    IS_HIDDEN=$(osascript -e "tell application \"System Events\" to (get visible of process \"$app_name\")" 2>/dev/null || echo "error")
    echo "DEBUG: Visibility check result: $IS_HIDDEN"

    if [ "$IS_HIDDEN" = "true" ]; then
      # App is visible, hide it
      echo "DEBUG: Attempting to hide $app_name"
      osascript -e "tell application \"System Events\" to set visible of process \"$app_name\" to false" 2>&1
    else
      # App is hidden, show it
      echo "DEBUG: Attempting to show $app_name"
      osascript -e "tell application \"$app_name\" to activate" 2>&1
    fi
    exit 0
  fi
done

# If we get here, no ghostty found
echo "DEBUG: No ghostty process found, launching..."
open -a ghostty

