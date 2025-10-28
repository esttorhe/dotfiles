#!/bin/sh

# Source shell profile to get proper PATH
export PATH="/Users/esteban.torres/.local/share/mise/shims:$PATH"

# Handle mouse click events
if [ "$SENDER" = "mouse.clicked" ]; then
    # Extract the space number from the item name (e.g., "space.1" -> "1")
    SPACE_ID="${NAME#*.}"
    # Focus the yabai space
    yabai -m space --focus "$SPACE_ID"
else
    # Regular space update
    # The $SELECTED variable is available for space components and indicates if
    # the space invoking this script (with name: $NAME) is currently selected:
    # https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item
    sketchybar --set "$NAME" background.drawing="$SELECTED"
fi
