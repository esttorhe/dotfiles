#!/bin/bash
# ABOUTME: Auto-setup script triggered by yabai display events
# ABOUTME: Automatically reconfigures workspace layout when displays are added/removed

set -e

EVENT_TYPE="$1"

get_display_count() {
  yabai -m query --displays | jq '. | length'
}

main() {
  local display_count=$(get_display_count)

  echo "Display event: $EVENT_TYPE detected. Current display count: $display_count"

  # Small delay to let display configuration settle
  sleep 2

  # Recalculate yabai top padding for new display configuration
  echo "Recalculating padding for display change..."
  ~/.config/yabai/scripts/update-padding.sh

  case $display_count in
  1)
    echo "Single display detected - running single display setup"
    ~/.config/yabai/scripts/yabai-workspace-setup.sh single
    ;;
  2)
    echo "Dual display detected - running dual display setup"
    ~/.config/yabai/scripts/yabai-workspace-setup.sh dual
    ;;
  *)
    echo "Triple+ display detected - running triple display setup"
    ~/.config/yabai/scripts/yabai-workspace-setup.sh triple
    ;;
  esac
}

main "$@"

