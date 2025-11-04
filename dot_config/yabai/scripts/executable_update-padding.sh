#!/usr/bin/env sh

# ABOUTME: Dynamically sets yabai top padding per display based on display type
# ABOUTME: Uses smaller padding for laptop display, larger for external displays

# Get all displays and configure padding per display
configure_display_padding() {
    local displays=$(yabai -m query --displays 2>/dev/null | jq -r '.[] | "\(.index) \(.frame.x) \(.frame.y)"')

    if [ -z "$displays" ]; then
        echo "No displays found"
        return
    fi

    # First, set global padding to a default
    yabai -m config top_padding 7

    echo "$displays" | while read -r display_index x_pos y_pos; do
        # Get display resolution to help identify laptop display
        display_info=$(yabai -m query --displays --display "$display_index")
        width=$(echo "$display_info" | jq -r '.frame.w')
        height=$(echo "$display_info" | jq -r '.frame.h')

        # Determine if this is the laptop display
        # Method 1: Check if it's the built-in display using system_profiler
        is_builtin=$(system_profiler SPDisplaysDataType | grep -A20 "Display Type: Built-In" | grep -q "Resolution: ${width%.0000} x ${height%.0000}" && echo "true" || echo "false")

        # Method 2: MacBook displays typically have specific resolutions
        is_macbook_resolution="false"
        case "${width}x${height}" in
            "1352.0000x878.0000"|"1680.0000x1050.0000"|"2048.0000x1280.0000"|"2560.0000x1600.0000"|"3024.0000x1890.0000"|"3456.0000x2160.0000")
                is_macbook_resolution="true"
                ;;
        esac

        # Override: environment variable takes precedence
        if [ -n "$LAPTOP_DISPLAY_INDEX" ] && [ "$display_index" = "$LAPTOP_DISPLAY_INDEX" ]; then
            is_laptop="true"
        elif [ "$is_builtin" = "true" ] || [ "$is_macbook_resolution" = "true" ]; then
            is_laptop="true"
        else
            is_laptop="false"
        fi

        if [ "$is_laptop" = "true" ]; then
            padding=7
            echo "Laptop display $display_index (${width}x${height}) - using padding: $padding"
        else
            padding=32
            echo "External display $display_index (${width}x${height}) - using padding: $padding"
        fi

        # Apply to all spaces on this display
        spaces=$(echo "$display_info" | jq -r '.spaces[]')
        for space in $spaces; do
            yabai -m config --space "$space" top_padding "$padding" 2>/dev/null
        done
    done

    echo "Set laptop padding to 7px, external displays to 32px"
}

# Configure padding for all displays
configure_display_padding

display_count=$(yabai -m query --displays 2>/dev/null | jq '. | length' 2>/dev/null || echo "1")
echo "Updated padding for $display_count display(s)"