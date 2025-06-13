#!/bin/bash
# User Interaction Utility
# Handles user prompts and interactions

# Ask a yes/no question
# Usage: ask_yes_no "Question?" [default]
# Default can be "y" or "n" (defaults to "n" if not specified)
ask_yes_no() {
    local prompt=$1
    local default=${2:-n}
    
    # If AUTO_YES is set, always return yes
    if [[ "$AUTO_YES" == true ]]; then
        return 0
    fi
    
    # If not running interactively, use default
    if [[ ! -t 0 ]]; then
        [[ "$default" == "y" ]]
        return $?
    fi
    
    local yn
    local prompt_suffix
    
    if [[ "$default" == "y" ]]; then
        prompt_suffix="[Y/n]"
    else
        prompt_suffix="[y/N]"
    fi
    
    while true; do
        read -p "$prompt $prompt_suffix: " yn
        
        # If empty response, use default
        if [[ -z "$yn" ]]; then
            yn=$default
        fi
        
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Ask for text input with optional default
# Usage: ask_input "Prompt" [default_value]
ask_input() {
    local prompt=$1
    local default=$2
    local input
    
    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " input
        echo "${input:-$default}"
    else
        read -p "$prompt: " input
        echo "$input"
    fi
}

# Select from a list of options
# Usage: ask_select "Prompt" option1 option2 option3...
ask_select() {
    local prompt=$1
    shift
    local options=("$@")
    local selected
    
    echo "$prompt"
    echo
    
    # Display options
    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[$i]}"
    done
    echo
    
    while true; do
        read -p "Enter selection (1-${#options[@]}): " selected
        
        # Validate selection
        if [[ "$selected" =~ ^[0-9]+$ ]] && [ "$selected" -ge 1 ] && [ "$selected" -le "${#options[@]}" ]; then
            echo "${options[$((selected-1))]}"
            return 0
        else
            echo "Invalid selection. Please enter a number between 1 and ${#options[@]}."
        fi
    done
}

# Confirm an action with details
# Usage: confirm_action "Action description" "Detail 1" "Detail 2"...
confirm_action() {
    local action=$1
    shift
    local details=("$@")
    
    echo
    print_warning "About to: $action"
    
    if [[ ${#details[@]} -gt 0 ]]; then
        echo "Details:"
        for detail in "${details[@]}"; do
            echo "  - $detail"
        done
    fi
    echo
    
    ask_yes_no "Do you want to proceed?"
}

# Pause and wait for user to press Enter
# Usage: pause_for_user [message]
pause_for_user() {
    local message=${1:-"Press Enter to continue..."}
    
    if [[ "$AUTO_YES" == true ]]; then
        return 0
    fi
    
    read -p "$message"
}

# Show a warning and ask to continue
# Usage: warn_and_continue "Warning message"
warn_and_continue() {
    local message=$1
    
    print_warning "$message"
    
    if [[ "$AUTO_YES" != true ]]; then
        if ! ask_yes_no "Continue anyway?"; then
            print_status "Operation cancelled by user"
            return 1
        fi
    fi
    
    return 0
}

# Multi-select from options
# Usage: ask_multiselect "Prompt" option1 option2 option3...
# Returns: Space-separated list of selected options
ask_multiselect() {
    local prompt=$1
    shift
    local options=("$@")
    local selected=()
    local done=false
    
    # Initialize selection array (all false)
    for i in "${!options[@]}"; do
        selected[$i]=false
    done
    
    echo "$prompt"
    echo "(Use space to select/deselect, Enter to confirm)"
    echo
    
    while [[ "$done" != true ]]; do
        # Display options with selection status
        for i in "${!options[@]}"; do
            if [[ "${selected[$i]}" == true ]]; then
                echo "  [x] $((i+1))) ${options[$i]}"
            else
                echo "  [ ] $((i+1))) ${options[$i]}"
            fi
        done
        echo
        echo "  0) Done selecting"
        echo
        
        read -p "Toggle option (1-${#options[@]}) or 0 to finish: " choice
        
        if [[ "$choice" == "0" ]]; then
            done=true
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            # Toggle selection
            local idx=$((choice-1))
            if [[ "${selected[$idx]}" == true ]]; then
                selected[$idx]=false
            else
                selected[$idx]=true
            fi
            # Clear screen and redraw
            clear
            echo "$prompt"
            echo "(Use space to select/deselect, Enter to confirm)"
            echo
        else
            echo "Invalid selection."
        fi
    done
    
    # Return selected options
    local result=""
    for i in "${!options[@]}"; do
        if [[ "${selected[$i]}" == true ]]; then
            result+="${options[$i]} "
        fi
    done
    
    echo "${result% }"  # Remove trailing space
}
