#!/usr/bin/env bash
# ABOUTME: Dynamically sets sketchybar y_offset based on primary display type at origin
# ABOUTME: Laptop displays need -37 offset, external displays need 0

# Get the display at origin (0,0) which is where sketchybar's "display=main" appears
main_display=$(yabai -m query --displays | jq '.[] | select(.frame.x == 0 and .frame.y == 0)' 2>/dev/null | head -1)

if [ -z "$main_display" ]; then
  echo "Could not find display at origin"
  exit 1
fi

width=$(echo "$main_display" | jq -r '.frame.w')
height=$(echo "$main_display" | jq -r '.frame.h')

# Check if this display is the laptop built-in display
is_builtin=$(system_profiler SPDisplaysDataType | grep -A20 "Display Type: Built-In" | grep -q "Resolution: ${width%.0000} x ${height%.0000}" && echo "true" || echo "false")

# MacBook display resolutions
is_macbook_resolution="false"
case "${width}x${height}" in
"1352.0000x878.0000" | "1680.0000x1050.0000" | "2048.0000x1280.0000" | "2560.0000x1600.0000" | "3024.0000x1890.0000" | "3456.0000x2160.0000")
  is_macbook_resolution="true"
  ;;
esac

if [ "$is_builtin" = "true" ] || [ "$is_macbook_resolution" = "true" ]; then
  Y_OFFSET=-35
  echo "Laptop display at origin (${width}x${height}) - using y_offset: $Y_OFFSET"
else
  Y_OFFSET=-35
  echo "External display at origin (${width}x${height}) - using y_offset: $Y_OFFSET"
fi

# Apply the offset
sketchybar --bar y_offset=$Y_OFFSET
