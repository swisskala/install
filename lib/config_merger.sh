#!/bin/bash
# Config Merger Library
# Handles merging of global and device-specific configurations
# Device configs have higher priority and can completely override global configs

# Merge configuration files with device config taking priority
# Usage: merge_configs "config_name" "device_name" "output_path"
merge_configs() {
    local config_name=$1
    local device_name=$2
    local output_path=$3
    
    # Remove .global suffix if present in config_name
    config_name="${config_name%.global}"
    
    local global_file="$CONFIG_PATH/global/${config_name}.global"
    local device_file="$CONFIG_PATH/devices/$device_name/${config_name}"
    
    if [[ "$VERBOSE" == true ]]; then
        print_status "Merging config: $config_name for device: $device_name"
        print_status "Global file: $global_file"
        print_status "Device file: $device_file"
    fi
    
    # Priority logic:
    # 1. If both device and global exist, merge them (device overrides global)
    # 2. If only device exists, use device
    # 3. If only global exists, use global
    # 4. If neither exists, still use global if available (fallback)
    
    if [[ -f "$device_file" ]] && [[ -f "$global_file" ]]; then
        # Both exist - merge with device taking priority
        if [[ "$VERBOSE" == true ]]; then
            print_status "Merging global and device configs (device takes priority)"
        fi
        
        # Determine merge strategy based on file type
        case "$config_name" in
            bashrc|bash_profile|profile|xinitrc)
                # For shell scripts, concatenate with device last (higher priority)
                merge_shell_configs "$global_file" "$device_file" "$output_path"
                ;;
            kitty.conf|picom.conf)
                # For key=value configs, smart merge
                merge_key_value_configs "$global_file" "$device_file" "$output_path"
                ;;
            i3/config|i3blocks/config|i3status/config)
                # For i3-style configs, use smart command merging
                merge_i3_configs "$global_file" "$device_file" "$output_path"
                ;;
            *)
                # Default: concatenate with clear sections
                merge_with_sections "$global_file" "$device_file" "$output_path"
                ;;
        esac
        print_success "Merged global + device config: $config_name"
        
    elif [[ -f "$device_file" ]]; then
        # Only device exists - use it
        if [[ "$VERBOSE" == true ]]; then
            print_status "Using device config only: $device_file"
        fi
        cp "$device_file" "$output_path"
        print_success "Applied device config: $config_name"
        
    elif [[ -f "$global_file" ]]; then
        # Only global exists or neither exists - use global as fallback
        if [[ "$VERBOSE" == true ]]; then
            print_status "Using global config (fallback): $global_file"
        fi
        cp "$global_file" "$output_path"
        print_success "Applied global config: $config_name"
        
    else
        # No config exists at all
        if [[ "$VERBOSE" == true ]]; then
            print_warning "No config found for: $config_name"
        fi
        return 1
    fi
    
    return 0
}

# Merge shell configuration files (bashrc, profile, etc)
merge_shell_configs() {
    local global_file=$1
    local device_file=$2
    local output_file=$3
    
    # Simple append logic: global first, then device-specific
    {
        # First, output the entire global bashrc
        cat "$global_file"
        
        # Add a clear separator
        echo ""
        echo ""
        echo "# ============================================="
        echo "# Device-Specific Configuration: $DEVICE_NAME"
        echo "# ============================================="
        echo ""
        
        # Then append everything from the device-specific bashrc
        cat "$device_file"
    } > "$output_file"
}

# Merge configuration files with key=value format
merge_conf_files() {
    local global_file=$1
    local device_file=$2
    local output_file=$3
    
    # For config files like kitty.conf, i3 config, etc.
    # Device settings override global settings
    
    # First, check if this is a key=value style config
    if grep -qE '^\s*[^#]\S+\s*=' "$global_file" 2>/dev/null; then
        # Key=value style (like kitty.conf)
        merge_key_value_configs "$global_file" "$device_file" "$output_file"
    else
        # Other config style (like i3 config with commands)
        merge_command_configs "$global_file" "$device_file" "$output_file"
    fi
}

# Merge key=value style configs (device overrides global)
merge_key_value_configs() {
    local global_file=$1
    local device_file=$2
    local output_file=$3
    
    # Create associative array for device settings
    declare -A device_settings
    
    # Read device settings
    if [[ -f "$device_file" ]]; then
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            # Extract key (everything before first = or space)
            if [[ "$line" =~ ^[[:space:]]*([^[:space:]=]+)[[:space:]]*[=[:space:]](.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                device_settings["$key"]=1
            fi
        done < "$device_file"
    fi
    
    # Process global file, skip lines that device overrides
    {
        echo "# Configuration for device: $DEVICE_NAME"
        echo "# Generated from global + device configs"
        echo ""
        
        while IFS= read -r line; do
            # Check if this line contains a key that device overrides
            local skip=false
            if [[ "$line" =~ ^[[:space:]]*([^[:space:]=]+)[[:space:]]*[=[:space:]] ]]; then
                local key="${BASH_REMATCH[1]}"
                if [[ -n "${device_settings[$key]:-}" ]]; then
                    skip=true
                fi
            fi
            
            # Output line if not overridden
            [[ "$skip" == false ]] && echo "$line"
        done < "$global_file"
        
        # Add device-specific settings
        echo ""
        echo "# Device-specific overrides"
        cat "$device_file"
    } > "$output_file"
}

# Merge i3-style configuration files
merge_i3_configs() {
    local global_file=$1
    local device_file=$2
    local output_file=$3
    
    # For i3 configs, we need to be smarter about merging
    # Device config can override specific bindings and settings
    
    declare -A device_bindings
    declare -A device_settings
    declare -A device_modes
    
    # Parse device file for bindings and settings to override
    if [[ -f "$device_file" ]]; then
        local in_mode=""
        while IFS= read -r line; do
            # Track mode blocks
            if [[ "$line" =~ ^mode[[:space:]]+\"([^\"]+)\" ]]; then
                in_mode="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]*\} ]] && [[ -n "$in_mode" ]]; then
                in_mode=""
            fi
            
            # Track bindsym/bindcode
            if [[ "$line" =~ ^[[:space:]]*(bindsym|bindcode)[[:space:]]+([^[:space:]]+) ]]; then
                local key="${BASH_REMATCH[2]}"
                if [[ -n "$in_mode" ]]; then
                    device_bindings["mode:$in_mode:$key"]=1
                else
                    device_bindings["$key"]=1
                fi
            fi
            
            # Track set commands
            if [[ "$line" =~ ^[[:space:]]*set[[:space:]]+(\$[^[:space:]]+) ]]; then
                device_settings["${BASH_REMATCH[1]}"]=1
            fi
            
            # Track other settings (font, gaps, etc)
            if [[ "$line" =~ ^[[:space:]]*(font|gaps|workspace|floating_modifier|focus_follows_mouse|default_border)[[:space:]] ]]; then
                device_settings["${BASH_REMATCH[1]}"]=1
            fi
        done < "$device_file"
    fi
    
    # Process global file, skip overridden parts
    {
        echo "# i3 Configuration for device: $DEVICE_NAME"
        echo "# Merged from global + device configs"
        echo ""
        
        local in_mode=""
        local skip_mode=false
        
        while IFS= read -r line; do
            # Track mode blocks
            if [[ "$line" =~ ^mode[[:space:]]+\"([^\"]+)\" ]]; then
                in_mode="${BASH_REMATCH[1]}"
                # Check if entire mode is redefined in device
                if grep -q "^mode[[:space:]]\+\"$in_mode\"" "$device_file" 2>/dev/null; then
                    skip_mode=true
                    continue
                fi
            elif [[ "$line" =~ ^[[:space:]]*\} ]] && [[ -n "$in_mode" ]]; then
                in_mode=""
                skip_mode=false
                echo "$line"
                continue
            fi
            
            [[ "$skip_mode" == true ]] && continue
            
            local skip=false
            
            # Check bindings
            if [[ "$line" =~ ^[[:space:]]*(bindsym|bindcode)[[:space:]]+([^[:space:]]+) ]]; then
                local key="${BASH_REMATCH[2]}"
                if [[ -n "$in_mode" ]]; then
                    [[ -n "${device_bindings[mode:$in_mode:$key]:-}" ]] && skip=true
                else
                    [[ -n "${device_bindings[$key]:-}" ]] && skip=true
                fi
            fi
            
            # Check set commands
            if [[ "$line" =~ ^[[:space:]]*set[[:space:]]+(\$[^[:space:]]+) ]]; then
                [[ -n "${device_settings[${BASH_REMATCH[1]}]:-}" ]] && skip=true
            fi
            
            # Check other settings
            if [[ "$line" =~ ^[[:space:]]*(font|gaps|workspace|floating_modifier|focus_follows_mouse|default_border)[[:space:]] ]]; then
                [[ -n "${device_settings[${BASH_REMATCH[1]}]:-}" ]] && skip=true
            fi
            
            [[ "$skip" == false ]] && echo "$line"
        done < "$global_file"
        
        echo ""
        echo "# ============================================="
        echo "# Device-specific configuration for $DEVICE_NAME"
        echo "# ============================================="
        cat "$device_file"
    } > "$output_file"
}

# Generic merge with clear sections
merge_with_sections() {
    local global_file=$1
    local device_file=$2
    local output_file=$3
    
    {
        echo "# ============================================="
        echo "# Configuration: Global + Device ($DEVICE_NAME)"
        echo "# ============================================="
        echo ""
        echo "# --- Global Configuration ---"
        cat "$global_file"
        echo ""
        echo ""
        echo "# --- Device-Specific Configuration ---"
        cat "$device_file"
    } > "$output_file"
}

# Check if a config exists for merging
config_exists_for_merge() {
    local config_name=$1
    local device_name=$2
    
    # Remove suffix
    config_name="${config_name%.global}"
    
    local global_file="$CONFIG_PATH/global/${config_name}.global"
    local device_file="$CONFIG_PATH/devices/$device_name/${config_name}"
    
    [[ -f "$global_file" ]] || [[ -f "$device_file" ]]
}

# List all available configs for a device
list_available_configs() {
    local device_name=$1
    
    print_status "Available configurations for device: $device_name"
    echo ""
    
    # Check global configs
    echo "Global configs:"
    for config in "$CONFIG_PATH/global"/*.global; do
        [[ -f "$config" ]] && echo "  - $(basename "$config" .global)"
    done
    
    echo ""
    echo "Device-specific configs:"
    
    # Check device configs
    for config in "$CONFIG_PATH/devices/$device_name"/*; do
        [[ -f "$config" ]] || continue
        local name=$(basename "$config")
        if [[ "$name" != "device.conf" ]]; then
            echo "  - $name"
        fi
    done
}
