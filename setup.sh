#!/bin/bash
# Main Setup Script - Modular System Configuration
# Supports multiple devices with global and device-specific configurations

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_PATH="$SCRIPT_DIR"
export CONFIG_PATH="$REPO_PATH/config"
export LIB_PATH="$REPO_PATH/lib"
export PACKAGES_PATH="$REPO_PATH/packages"
export STEPS_PATH="$REPO_PATH/steps"
export UTILS_PATH="$REPO_PATH/utils"
export SCRIPTS_PATH="$REPO_PATH/scripts"

# Default values
DEVICE_NAME=""
DRY_RUN=false
SKIP_PACKAGES=false
SKIP_CONFIGS=false
SKIP_FONTS=false
SKIP_LOCALE=false
VERBOSE=false
AUTO_YES=false

# Source all utilities and libraries
for util in "$UTILS_PATH"/*.sh; do
    [[ -f "$util" ]] && source "$util"
done

for lib in "$LIB_PATH"/*.sh; do
    [[ -f "$lib" ]] && source "$lib"
done

# Source all step functions
for step in "$STEPS_PATH"/*.sh; do
    [[ -f "$step" ]] && source "$step"
done

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Modular system setup script with device-specific configurations.

OPTIONS:
    --device NAME        Specify device name (surfarch, thinkarch, legacy)
    --dry-run           Show what would be done without making changes
    --skip-packages     Skip package installation
    --skip-configs      Skip configuration file deployment
    --skip-fonts        Skip font installation
    --skip-locale       Skip locale configuration
    --verbose           Show detailed output
    --yes, -y           Answer yes to all prompts
    --help, -h          Show this help message

EXAMPLES:
    $0                          # Auto-detect device and run full setup
    $0 --device surfarch        # Setup for surfarch device
    $0 --dry-run               # Test run without changes
    $0 --skip-packages         # Only deploy configurations

EOF
    exit 0
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --device)
                DEVICE_NAME="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-packages)
                SKIP_PACKAGES=true
                shift
                ;;
            --skip-configs)
                SKIP_CONFIGS=true
                shift
                ;;
            --skip-fonts)
                SKIP_FONTS=true
                shift
                ;;
            --skip-locale)
                SKIP_LOCALE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --yes|-y)
                AUTO_YES=true
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Detect or validate device
setup_device() {
    if [[ -z "$DEVICE_NAME" ]]; then
        print_status "Auto-detecting device..."
        DEVICE_NAME=$(detect_device)
        
        if [[ -z "$DEVICE_NAME" || "$DEVICE_NAME" == "generic" ]]; then
            print_warning "Could not auto-detect device"
            echo "Available devices:"
            for device_dir in "$CONFIG_PATH/devices"/*; do
                [[ -d "$device_dir" ]] && echo "  - $(basename "$device_dir")"
            done
            
            read -p "Please enter device name: " DEVICE_NAME
        fi
    fi
    
    # Validate device configuration exists
    if [[ ! -d "$CONFIG_PATH/devices/$DEVICE_NAME" ]]; then
        print_error "Device configuration not found: $CONFIG_PATH/devices/$DEVICE_NAME"
        print_status "Available devices:"
        for device_dir in "$CONFIG_PATH/devices"/*; do
            [[ -d "$device_dir" ]] && echo "  - $(basename "$device_dir")"
        done
        exit 1
    fi
    
    # Load device configuration
    if [[ -f "$CONFIG_PATH/devices/$DEVICE_NAME/device.conf" ]]; then
        print_status "Loading device configuration for: $DEVICE_NAME"
        source "$CONFIG_PATH/devices/$DEVICE_NAME/device.conf"
        print_success "Device configuration loaded"
    else
        print_warning "No device.conf found for $DEVICE_NAME, using defaults"
    fi
    
    export DEVICE_NAME
}

# Show setup plan
show_setup_plan() {
    echo
    print_status "Setup Plan Summary"
    echo "=================="
    echo "Device:          $DEVICE_NAME"
    echo "System:          $SYSTEM"
    echo "Dry Run:         $DRY_RUN"
    echo
    echo "Steps to perform:"
    [[ "$SKIP_PACKAGES" != true ]] && echo "  ✓ Update system and install packages"
    [[ "$SKIP_FONTS" != true ]] && echo "  ✓ Install fonts"
    [[ "$SKIP_CONFIGS" != true ]] && echo "  ✓ Deploy configuration files"
    [[ "$SKIP_LOCALE" != true ]] && echo "  ✓ Configure locale settings"
    echo
    
    if [[ "$AUTO_YES" != true ]] && [[ "$DRY_RUN" != true ]]; then
        if ! ask_yes_no "Do you want to proceed with this setup?"; then
            print_status "Setup cancelled by user"
            exit 0
        fi
    fi
}

# Install packages from lists
install_from_lists() {
    local package_lists=(
        "$PACKAGES_PATH/global.list"
        "$PACKAGES_PATH/$SYSTEM.list"
        "$PACKAGES_PATH/devices/$DEVICE_NAME.list"
    )
    
    # Collect all packages
    local all_packages=()
    
    for list_file in "${package_lists[@]}"; do
        if [[ -f "$list_file" ]]; then
            print_status "Reading packages from: $(basename "$list_file")"
            while IFS= read -r package; do
                # Skip empty lines and comments
                [[ -z "$package" || "$package" =~ ^[[:space:]]*# ]] && continue
                # Trim whitespace
                package=$(echo "$package" | xargs)
                all_packages+=("$package")
            done < "$list_file"
        fi
    done
    
    # Remove duplicates
    local unique_packages=($(printf '%s\n' "${all_packages[@]}" | sort -u))
    
    if [[ ${#unique_packages[@]} -eq 0 ]]; then
        print_warning "No packages to install"
        return 0
    fi
    
    print_status "Installing ${#unique_packages[@]} packages..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN - Would install:"
        printf '%s\n' "${unique_packages[@]}" | column
        return 0
    fi
    
    # Install packages based on system type
    if [[ "$SYSTEM" == "arch" ]]; then
        # Use yay for AUR packages if available
        if command -v yay &> /dev/null; then
            yay -S --needed --noconfirm "${unique_packages[@]}"
        else
            sudo pacman -S --needed --noconfirm "${unique_packages[@]}"
        fi
    elif [[ "$SYSTEM" == "debian" ]]; then
        sudo apt install -y "${unique_packages[@]}"
    fi
}

# Deploy configuration files
deploy_configurations() {
    print_status "Deploying configuration files for device: $DEVICE_NAME"
    
    local configs=(
        "bashrc:$HOME/.bashrc"
        "bash_profile:$HOME/.bash_profile"
        "profile:$HOME/.profile"
        "kitty.conf:$HOME/.config/kitty/kitty.conf"
        "i3/config:$HOME/.config/i3/config"
        "i3blocks/config:$HOME/.config/i3blocks/config"
        "i3status/config:$HOME/.config/i3status/config"
        "picom.conf:$HOME/.config/picom.conf"
        "xinitrc:$HOME/.xinitrc"
        "kglobalshortcutsrc:$HOME/.config/kglobalshortcutsrc"
    )
    
    for config_pair in "${configs[@]}"; do
        IFS=':' read -r config_name target_path <<< "$config_pair"
        
        # Skip if no global config exists
        local global_config="$CONFIG_PATH/global/${config_name}.global"
        [[ ! -f "$global_config" ]] && continue
        
        print_status "Processing: $config_name"
        
        if [[ "$DRY_RUN" == true ]]; then
            print_status "DRY RUN - Would deploy $config_name to $target_path"
            continue
        fi
        
        # Create target directory
        mkdir -p "$(dirname "$target_path")"
        
        # Backup existing file
        if [[ -f "$target_path" ]]; then
            local backup_path="${target_path}.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$target_path" "$backup_path"
            print_status "Backup created: $backup_path"
        fi
        
        # Merge global and device-specific configs
        merge_configs "$config_name" "$DEVICE_NAME" "$target_path"
        
        # Process templates with device variables
        if [[ -f "$CONFIG_PATH/devices/$DEVICE_NAME/device.conf" ]]; then
            process_template "$target_path" "$target_path" "$CONFIG_PATH/devices/$DEVICE_NAME/device.conf"
        fi
        
        print_success "Deployed: $config_name"
    done
}

# Deploy scripts (like llm-remote)
deploy_scripts() {
    print_status "Deploying system scripts..."
    
    # Deploy llm-remote script
    local llm_script="$SCRIPTS_PATH/llm-remote-$SYSTEM"
    if [[ -f "$llm_script" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            print_status "DRY RUN - Would install llm-remote to /usr/local/bin/"
            return 0
        fi
        
        if ask_yes_no "Install llm-remote script?"; then
            sudo cp "$llm_script" "/usr/local/bin/llm-remote"
            sudo chmod +x "/usr/local/bin/llm-remote"
            print_success "llm-remote script installed"
        fi
    fi
}

# Main execution function
main() {
    echo "========================================="
    echo "    Modular System Setup Script"
    echo "========================================="
    echo
    
    # Detect system type
    detect_system
    
    # Setup device configuration
    setup_device
    
    # Show setup plan and confirm
    show_setup_plan
    
    # Step 1: Update system
    if [[ "$SKIP_PACKAGES" != true ]]; then
        update_system
    fi
    
    # Step 2: Install yay (Arch only)
    if [[ "$SKIP_PACKAGES" != true ]] && [[ "$SYSTEM" == "arch" ]]; then
        install_yay
    fi
    
    # Step 3: Install packages from lists
    if [[ "$SKIP_PACKAGES" != true ]]; then
        install_from_lists
    fi
    
    # Step 4: Install fonts
    if [[ "$SKIP_FONTS" != true ]]; then
        install_nerd_font
    fi
    
    # Step 5: Deploy configurations
    if [[ "$SKIP_CONFIGS" != true ]]; then
        deploy_configurations
    fi
    
    # Step 6: Deploy scripts
    if [[ "$SKIP_CONFIGS" != true ]]; then
        deploy_scripts
    fi
    
    # Step 7: Configure locale
    if [[ "$SKIP_LOCALE" != true ]]; then
        configure_locale
    fi
    
    # Post-setup summary
    echo
    print_success "Setup completed successfully!"
    echo
    print_status "Post-setup notes:"
    echo "  • Run 'source ~/.bashrc' to reload shell configuration"
    echo "  • Restart your terminal for font changes to take effect"
    echo "  • Log out and back in for all changes to take full effect"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo
        print_warning "This was a DRY RUN - no changes were made"
        print_status "Run without --dry-run to apply changes"
    fi
}

# Parse arguments and run
parse_arguments "$@"
main "$@"
