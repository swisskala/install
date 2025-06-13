#!/bin/bash
# Device Detection Library
# Detects device name using multiple methods

detect_device() {
    local device_name=""
    
    # Method 1: Try hostname command
    if command -v hostname &> /dev/null; then
        device_name=$(hostname)
    # Method 2: Try reading /etc/hostname
    elif [[ -f /etc/hostname ]]; then
        device_name=$(cat /etc/hostname | tr -d '\n')
    # Method 3: Try hostnamectl
    elif command -v hostnamectl &> /dev/null; then
        device_name=$(hostnamectl --static)
    # Method 4: Try reading from /proc/sys/kernel/hostname
    elif [[ -f /proc/sys/kernel/hostname ]]; then
        device_name=$(cat /proc/sys/kernel/hostname | tr -d '\n')
    # Method 5: Use uname
    elif command -v uname &> /dev/null; then
        device_name=$(uname -n)
    # Method 6: Check environment variable
    elif [[ -n "$HOSTNAME" ]]; then
        device_name="$HOSTNAME"
    fi
    
    # Validate device name
    if [[ -z "$device_name" ]]; then
        print_warning "Could not determine hostname"
        return 1
    fi
    
    # Check if device config exists
    if [[ -d "$CONFIG_PATH/devices/$device_name" ]]; then
        echo "$device_name"
        return 0
    fi
    
    # Check common device names
    case "$device_name" in
        surfarch|thinkarch|legacy)
            echo "$device_name"
            return 0
            ;;
    esac
    
    # Try to detect based on hardware characteristics
    print_status "Device config not found for hostname: $device_name"
    print_status "Attempting hardware-based detection..."
    
    # Check for specific hardware indicators
    local cpu_info=""
    local gpu_info=""
    
    if [[ -f /proc/cpuinfo ]]; then
        cpu_info=$(grep "model name" /proc/cpuinfo | head -1)
    fi
    
    if command -v lspci &> /dev/null; then
        gpu_info=$(lspci 2>/dev/null | grep -i vga)
    elif [[ -f /sys/class/graphics/fb0/device/uevent ]]; then
        gpu_info=$(cat /sys/class/graphics/fb0/device/uevent 2>/dev/null)
    fi
    
    # Check for specific patterns
    if echo "$gpu_info" | grep -qi "nvidia"; then
        # Check if it's a high-end system (might be surfarch)
        if echo "$cpu_info" | grep -qi "AMD Ryzen"; then
            print_status "Detected AMD Ryzen + NVIDIA (possibly surfarch)"
            # Still return generic unless confirmed
        fi
    fi
    
    # Check disk size to distinguish desktop from laptop
    local disk_size=0
    if command -v lsblk &> /dev/null; then
        disk_size=$(lsblk -b -d -o SIZE -n | head -1 2>/dev/null || echo 0)
        if [[ $disk_size -gt 500000000000 ]]; then  # > 500GB
            print_status "Large disk detected (desktop system?)"
        fi
    fi
    
    # Return generic if no specific device detected
    echo "generic"
    return 1
}

# Get current hostname using multiple methods
get_hostname() {
    local hostname=""
    
    # Try various methods to get hostname
    if command -v hostname &> /dev/null; then
        hostname=$(hostname)
    elif [[ -f /etc/hostname ]]; then
        hostname=$(cat /etc/hostname | tr -d '\n')
    elif command -v hostnamectl &> /dev/null; then
        hostname=$(hostnamectl --static)
    elif [[ -f /proc/sys/kernel/hostname ]]; then
        hostname=$(cat /proc/sys/kernel/hostname | tr -d '\n')
    elif command -v uname &> /dev/null; then
        hostname=$(uname -n)
    elif [[ -n "$HOSTNAME" ]]; then
        hostname="$HOSTNAME"
    else
        hostname="unknown"
    fi
    
    echo "$hostname"
}

# List available device configurations
list_device_configs() {
    print_status "Available device configurations:"
    
    if [[ -d "$CONFIG_PATH/devices" ]]; then
        for device_dir in "$CONFIG_PATH/devices"/*; do
            if [[ -d "$device_dir" ]]; then
                local device_name=$(basename "$device_dir")
                echo -n "  - $device_name"
                
                # Show if it's the current hostname
                local current_host=$(get_hostname)
                if [[ "$device_name" == "$current_host" ]]; then
                    echo " (current hostname)"
                else
                    echo ""
                fi
            fi
        done
    else
        print_error "No devices directory found at: $CONFIG_PATH/devices"
    fi
}

# Validate device name
validate_device() {
    local device_name=$1
    
    if [[ -z "$device_name" ]]; then
        return 1
    fi
    
    if [[ -d "$CONFIG_PATH/devices/$device_name" ]]; then
        return 0
    fi
    
    return 1
}
