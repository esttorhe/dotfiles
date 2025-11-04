#!/usr/bin/env sh

# ABOUTME: Dynamically sets yabai top padding based on display configuration
# ABOUTME: Uses smaller padding for laptop-only, larger for external displays

# Get display count
get_display_count() {
    yabai -m query --displays 2>/dev/null | jq '. | length' 2>/dev/null || echo "1"
}

# Get the appropriate padding based on display configuration
get_appropriate_padding() {
    local display_count=$(get_display_count)

    if [ "$display_count" -eq 1 ]; then
        # Laptop only - use the original smaller padding
        echo "7"
    else
        # External displays connected - use larger padding
        echo "37"
    fi
}

# Get the appropriate padding
top_padding=$(get_appropriate_padding)
display_count=$(get_display_count)

# Apply the padding
yabai -m config top_padding "$top_padding"

if [ "$display_count" -eq 1 ]; then
    echo "Updated yabai top_padding to: $top_padding (laptop-only mode)"
else
    echo "Updated yabai top_padding to: $top_padding (external display mode, $display_count displays)"
fi