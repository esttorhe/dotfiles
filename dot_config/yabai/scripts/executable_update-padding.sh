#!/usr/bin/env sh

# ABOUTME: Dynamically sets yabai top padding based on sketchybar height + 7px
# ABOUTME: This ensures consistent spacing regardless of display configuration

# Get the current sketchybar height
sketchybar_height=$(sketchybar --query bar | jq -r '.height // 30')

# Calculate the top padding (sketchybar height + 7px gap)
top_padding=$((sketchybar_height + 7))

# Apply the dynamic padding
yabai -m config top_padding "$top_padding"

echo "Updated yabai top_padding to: $top_padding (sketchybar height: $sketchybar_height + 7px gap)"