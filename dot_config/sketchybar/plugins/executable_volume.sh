#!/bin/sh

# The volume_change event supplies a $INFO variable in which the current volume
# percentage is passed to the script.

update_volume_display() {
  local VOLUME="$1"

  case "$VOLUME" in
    [6-9][0-9]|100) ICON="󰕾"
    ;;
    [3-5][0-9]) ICON="󰖀"
    ;;
    [1-9]|[1-2][0-9]) ICON="󰕿"
    ;;
    *) ICON="󰖁"
  esac

  sketchybar --set "$NAME" icon="$ICON" label="$VOLUME%"
}

if [ "$SENDER" = "volume_change" ]; then
  VOLUME="$INFO"
  update_volume_display "$VOLUME"

elif [ "$SENDER" = "mouse.clicked" ]; then
  case "$BUTTON" in
    "left")
      # Left click: Show volume popup
      current_volume=$(osascript -e "output volume of (get volume settings)")
      mute_status=$(osascript -e "output muted of (get volume settings)")

      if [ "$mute_status" = "true" ]; then
        popup_text="Volume: Muted"
      else
        popup_text="Volume: ${current_volume}%"
      fi

      sketchybar --set "$NAME" popup.drawing=on \
                          popup.label="$popup_text"

      # Hide popup after 2 seconds
      (sleep 2; sketchybar --set "$NAME" popup.drawing=off) &
      ;;
    "right")
      # Right click: Toggle mute
      current_volume=$(osascript -e "output volume of (get volume settings)")
      mute_status=$(osascript -e "output muted of (get volume settings)")

      if [ "$mute_status" = "true" ]; then
        # Unmute
        osascript -e "set volume output muted false"
        update_volume_display "$current_volume"
      else
        # Mute
        osascript -e "set volume output muted true"
        sketchybar --set "$NAME" icon="󰖁" label="Muted"
      fi
      ;;
  esac

elif [ "$SENDER" = "mouse.scrolled" ]; then
  # Scroll wheel: Adjust volume in 5% increments
  current_volume=$(osascript -e "output volume of (get volume settings)")


  # SketchyBar scroll: negative = up, positive = down (inverted from expected)
  if [ "$SCROLL_DELTA" -lt 0 ]; then
    # Scroll up: increase volume
    new_volume=$((current_volume + 5))
    [ "$new_volume" -gt 100 ] && new_volume=100
  else
    # Scroll down: decrease volume
    new_volume=$((current_volume - 5))
    [ "$new_volume" -lt 0 ] && new_volume=0
  fi

  osascript -e "set volume output volume $new_volume"
  update_volume_display "$new_volume"

fi
