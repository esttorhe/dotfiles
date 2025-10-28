#!/bin/sh

# Extract the space number from the item name (e.g., "space.1" -> "1")
SPACE_ID="${NAME#*.}"

# Focus the yabai space
yabai -m space --focus "$SPACE_ID"