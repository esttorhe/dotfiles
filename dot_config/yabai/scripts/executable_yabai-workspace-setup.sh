#!/bin/bash
# ABOUTME: Yabai workspace setup script for different display configurations
# ABOUTME: Handles single, dual, and triple display setups with automatic app placement

set -e

DISPLAY_MODE="${1:-single}"

setup_spaces() {
  local num_displays=$1

  # Get display indices dynamically
  local displays=($(yabai -m query --displays | jq -r '.[].index' | sort -n))
  local main_display=${displays[0]}
  local secondary_display=${displays[1]:-}
  local tertiary_display=${displays[2]:-}

  echo "Detected displays: ${displays[*]}"
  echo "Main display (your configured main): $main_display"

  # Only create spaces if we don't have enough
  local current_spaces=$(yabai -m query --spaces | jq '. | length')
  local needed_spaces=10

  echo "Current spaces: $current_spaces, needed: $needed_spaces"

  if [ "$current_spaces" -lt "$needed_spaces" ]; then
    local spaces_to_create=$((needed_spaces - current_spaces))
    echo "Creating $spaces_to_create additional spaces..."
    for i in $(seq 1 $spaces_to_create); do
      yabai -m space --create 2>/dev/null || true
    done
  else
    echo "Sufficient spaces exist, skipping creation"
  fi

  # Configure space layouts based on display count
  case $num_displays in
  1) # Single display - all spaces on main display
    echo "Setting up single display workspace..."
    # All spaces stay on the main display by default
    ;;
  2) # Dual display - distribute spaces using labels
    echo "Setting up dual display workspace..."
    echo "Moving labeled spaces to secondary display: $secondary_display"
    # Main display (your external): dev, notion (primary work)
    # Secondary display (laptop): communications, calendar, productivity, media
    yabai -m space discord --display $secondary_display 2>/dev/null || true
    yabai -m space telegram --display $secondary_display 2>/dev/null || true
    yabai -m space whatsapp --display $secondary_display 2>/dev/null || true
    yabai -m space calendar --display $secondary_display 2>/dev/null || true
    yabai -m space asana --display $secondary_display 2>/dev/null || true
    yabai -m space spotify --display $secondary_display 2>/dev/null || true
    yabai -m space slack --display $secondary_display 2>/dev/null || true
    ;;
  3) # Triple display - spread across all three using labels
    echo "Setting up triple display workspace..."
    echo "Moving labeled spaces to secondary: $secondary_display, tertiary: $tertiary_display"
    # Main display (your external): dev, notion (primary work)
    # Secondary display: communications and productivity
    # Tertiary display: calendar, media, and additional tools
    yabai -m space discord --display $secondary_display 2>/dev/null || true
    yabai -m space telegram --display $secondary_display 2>/dev/null || true
    yabai -m space whatsapp --display $secondary_display 2>/dev/null || true
    yabai -m space asana --display $secondary_display 2>/dev/null || true
    yabai -m space slack --display $secondary_display 2>/dev/null || true

    yabai -m space calendar --display $tertiary_display 2>/dev/null || true
    yabai -m space zen --display $tertiary_display 2>/dev/null || true
    yabai -m space spotify --display $tertiary_display 2>/dev/null || true
    ;;
  esac
}

move_existing_windows() {
  echo "Moving existing windows to proper spaces..."

  # Move windows for each app to their designated space
  move_app_windows() {
    local app="$1"
    local space="$2"
    echo "Moving $app windows to space $space"
    yabai -m query --windows | jq -r ".[] | select(.app==\"$app\") | .id" | while read -r window_id; do
      if [[ -n "$window_id" ]]; then
        yabai -m window "$window_id" --space "$space" 2>/dev/null || true
      fi
    done
  }

  # Move each app to its designated labeled space (matching yabairc rules)
  move_app_windows "Neovide" "dev"
  move_app_windows "Discord" "discord"
  move_app_windows "Telegram" "telegram"
  move_app_windows "WhatsApp" "whatsapp"
  move_app_windows "‎WhatsApp" "whatsapp" # Handle the weird WhatsApp name with invisible char
  move_app_windows "Notion" "notion"
  move_app_windows "Notion Calendar" "calendar"
  move_app_windows "Asana" "asana"
  move_app_windows "Zen" "zen"
  move_app_windows "Spotify" "spotify"
  move_app_windows "Slack" "slack"
}

launch_and_arrange_apps() {
  echo "Moving existing windows and launching missing applications..."

  # First, move existing windows to correct spaces
  move_existing_windows

  # Then launch any missing applications (only if not already running)
  # Development workspace (Space 1)
  if ! pgrep -x "Neovide" >/dev/null && ! pgrep -x "wezterm-gui" >/dev/null; then
    if command -v neovide >/dev/null; then
      open -a "Neovide" && sleep 2
    elif pgrep -x "WezTerm" >/dev/null; then
      echo "WezTerm already running"
    else
      open -a "wezterm-gui" && sleep 2
    fi
  fi

  # Communication workspaces - launch if not running
  if ! pgrep -x "Discord" >/dev/null; then
    open -a "Discord" && sleep 2
  fi

  if ! pgrep -x "Telegram" >/dev/null; then
    open -a "Telegram" && sleep 2
  fi

  if ! pgrep -x "WhatsApp" >/dev/null; then
    open -a "WhatsApp" && sleep 2
  fi

  if ! pgrep -x "Slack" >/dev/null; then
    open -a "Slack" && sleep 2
  fi

  # Productivity workspaces - launch if not running
  if ! pgrep -x "Notion" >/dev/null; then
    open -a "Notion" && sleep 2
  fi

  if ! pgrep -x "Notion Calendar" >/dev/null; then
    open -a "Notion Calendar" && sleep 2
  fi

  # Music/Media workspace - launch if not running
  if ! pgrep -x "Spotify" >/dev/null; then
    open -a "Spotify" && sleep 2
  fi

  # Move any newly launched windows after a brief delay
  sleep 3
  move_existing_windows

  # Focus development workspace to start
  yabai -m space --focus dev
}

get_display_count() {
  yabai -m query --displays | jq '. | length'
}

main() {
  case $DISPLAY_MODE in
  "single")
    setup_spaces 1
    launch_and_arrange_apps
    ;;
  "dual")
    setup_spaces 2
    launch_and_arrange_apps
    ;;
  "triple")
    setup_spaces 3
    launch_and_arrange_apps
    ;;
  "auto")
    local display_count=$(get_display_count)
    echo "Auto-detected $display_count displays"
    case $display_count in
    1) setup_spaces 1 ;;
    2) setup_spaces 2 ;;
    *) setup_spaces 3 ;;
    esac
    launch_and_arrange_apps

    # Ensure sketchybar appears on all displays after setup
    echo "Configuring sketchybar for all displays..."
    sketchybar --bar display=all
    ;;
  *)
    echo "Usage: $0 {single|dual|triple|auto}"
    echo "  single - Single display (laptop only)"
    echo "  dual   - Dual display (laptop + 1 external)"
    echo "  triple - Triple display (laptop + 2 external)"
    echo "  auto   - Auto-detect display count"
    exit 1
    ;;
  esac

  # Final sketchybar configuration to ensure it appears on all displays
  echo "Final sketchybar display configuration..."
  sketchybar --bar display=all

  echo "Workspace setup complete for $DISPLAY_MODE display mode!"
}

main "$@"
