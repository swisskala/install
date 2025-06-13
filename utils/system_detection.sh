#!/bin/bash
# System Detection Utility

detect_system() {
    if [[ -f /etc/arch-release ]]; then
        SYSTEM="arch"
    elif [[ -f /etc/debian_version ]]; then
        SYSTEM="debian"
    elif [[ -f /etc/fedora-release ]]; then
        SYSTEM="fedora"
    elif [[ -f /etc/redhat-release ]]; then
        SYSTEM="redhat"
    else
        SYSTEM="unknown"
    fi
    
    export SYSTEM
    print_status "Detected system: $SYSTEM"
}

# Get system information
get_system_info() {
    echo "System Information:"
    echo "=================="
    echo "OS Type: $SYSTEM"
    
    if command -v lsb_release &> /dev/null; then
        echo "Distribution: $(lsb_release -d | cut -f2)"
        echo "Version: $(lsb_release -r | cut -f2)"
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "Distribution: $NAME"
        echo "Version: $VERSION"
    fi
    
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
}
