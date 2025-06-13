#!/bin/bash
# Template Engine Library
# Processes configuration templates with variable substitution

# Process template file with variable substitution
# Usage: process_template "input_file" "output_file" "device_config_file"
process_template() {
    local input_file=$1
    local output_file=$2
    local device_config=$3
    
    if [[ ! -f "$input_file" ]]; then
        print_error "Template input file not found: $input_file"
        return 1
    fi
    
    if [[ ! -f "$device_config" ]]; then
        print_warning "Device config not found: $device_config"
        # Don't fail, just skip processing
        return 0
    fi
    
    # Source device config to get variables
    source "$device_config"
    
    # Create temp file
    local temp_file="${output_file}.tmp"
    cp "$input_file" "$temp_file"
    
    # Get all variables from device config
    local variables=$(grep -E '^[A-Z_]+=' "$device_config" | cut -d= -f1)
    
    # Replace each variable
    for var in $variables; do
        local value="${!var}"
        # Escape special characters in value for sed
        value=$(echo "$value" | sed 's/[[\.*^$()+?{|]/\\&/g')
        # Replace {{VARIABLE}} with value
        sed -i "s/{{$var}}/$value/g" "$temp_file"
    done
    
    # Move temp file to output
    mv "$temp_file" "$output_file"
}

# List all template variables in a file
# Usage: list_template_vars "file"
list_template_vars() {
    local file=$1
    grep -o '{{[A-Z_]*}}' "$file" 2>/dev/null | sort -u | sed 's/[{}]//g'
}

# Validate template against device config
# Usage: validate_template "template_file" "device_config"
validate_template() {
    local template_file=$1
    local device_config=$2
    
    local missing_vars=()
    local template_vars=$(list_template_vars "$template_file")
    
    # Source device config
    source "$device_config"
    
    for var in $template_vars; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_warning "Missing variables in device config:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        return 1
    fi
    
    return 0
}
