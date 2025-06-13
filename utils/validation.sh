#!/bin/bash
# Validation Utility Functions

# Validate directory exists
validate_directory() {
    local dir=$1
    local create=${2:-false}
    
    if [[ ! -d "$dir" ]]; then
        if [[ "$create" == true ]]; then
            mkdir -p "$dir"
            return $?
        else
            return 1
        fi
    fi
    return 0
}

# Validate file exists
validate_file() {
    local file=$1
    [[ -f "$file" ]]
}

# Validate command exists
validate_command() {
    local cmd=$1
    command -v "$cmd" &> /dev/null
}

# Validate package is installed
validate_package() {
    local package=$1
    
    case "$SYSTEM" in
        arch)
            pacman -Q "$package" &> /dev/null
            ;;
        debian)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        *)
            return 1
            ;;
    esac
}
