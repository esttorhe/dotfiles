#!/bin/bash
# ABOUTME: Toggle Ghostty terminal visibility with ctrl+alt+z
# ABOUTME: Uses macOS System Events to show/hide the application

APP_NAME="Ghostty"

# Check if Ghostty is running
if ! pgrep -f "Ghostty.app" >/dev/null; then
  # Not running, launch it
  open -a "$APP_NAME"
  exit 0
fi

# Check if visible using System Events
IS_VISIBLE=$(osascript -e "tell application \"System Events\" to get visible of process \"$APP_NAME\"" 2>/dev/null)

if [ "$IS_VISIBLE" = "true" ]; then
  # Visible, hide it
  osascript -e "tell application \"System Events\" to set visible of process \"$APP_NAME\" to false"
else
  # Hidden, show and activate it
  osascript -e "tell application \"$APP_NAME\" to activate"
fi
