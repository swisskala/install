#!/bin/bash
# Modular System Setup Script
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
VERBOSE=true
AUTO_YES=false
SYSTEM=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Basic print functions (before sourcing utils)
print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Check and source required files
check_required_files() {
    local required_libs=(
        "$LIB_PATH/config_merger.sh"
        "$LIB_PATH/device_detector.sh"
        "$LIB_PATH/template_engine.sh"
    )
    
    local required_utils=(
        "$UTILS_PATH/system_detection.sh"
        "$UTILS_PATH/user_interaction.sh"
    )
    
    local required_steps=(
        "$STEPS_PATH/update_system.sh"
        "$STEPS_PATH/install_software.sh"
        "$STEPS_PATH/install_fonts.sh"
        "$STEPS_PATH/configure_locale.sh"
    )
    
    # Check libraries
    for lib in "${required_libs[@]}"; do
        if [[ ! -f "$lib" ]]; then
            print_error "Required library not found: $lib"
            print_status "Creating placeholder for: $(basename "$lib")"
            create_placeholder_lib "$(basename "$lib")" "$lib"
        fi
    done
    
    # Check utilities
    for util in "${required_utils[@]}"; do
        if [[ ! -f "$util" ]]; then
            print_error "Required utility not found: $util"
            print_status "Creating placeholder for: $(basename "$util")"
            create_placeholder_util "$(basename "$util")" "$util"
        fi
    done
    
    # Check steps
    for step in "${required_steps[@]}"; do
        if [[ ! -f "$step" ]]; then
            print_error "Required step not found: $step"
            print_status "Creating placeholder for: $(basename "$step")"
            create_placeholder_step "$(basename "$step")" "$step"
        fi
    done
}

# Create placeholder functions for missing files
create_placeholder_lib() {
    local name=$1
    local path=$2
    
    case "$name" in
        "device_detector.sh")
            cat > "$path" << 'EOF'
#!/bin/bash
# Device Detection Library

detect_device() {
    local hostname=$(hostname)
    
    # Check if device config exists
    if [[ -d "$CONFIG_PATH/devices/$hostname" ]]; then
        echo "$hostname"
        return 0
    fi
    
    # Fallback detection
    case "$hostname" in
        surfarch|thinkarch|legacy)
            echo "$hostname"
            ;;
        *)
            echo "generic"
            ;;
    esac
}
EOF
            ;;
        "template_engine.sh")
            cat > "$path" << 'EOF'
#!/bin/bash
# Template Engine Library

process_template() {
    local input_file=$1
    local output_file=$2
    local device_config=$3
    
    # Source device config to get variables
    source "$device_config"
    
    # Copy input to output with variable substitution
    cp "$input_file" "$output_file.tmp"
    
    # Replace all {{VARIABLE}} patterns
    while IFS= read -r line; do
        if [[ "$line" =~ \{\{([A-Z_]+)\}\} ]]; then
            var_name="${BASH_REMATCH[1]}"
            var_value="${!var_name:-}"
            sed -i "s/{{$var_name}}/$var_value/g" "$output_file.tmp"
        fi
    done < "$input_file"
    
    mv "$output_file.tmp" "$output_file"
}
EOF
            ;;
    esac
    chmod +x "$path"
}

create_placeholder_util() {
    local name=$1
    local path=$2
    
    case "$name" in
        "system_detection.sh")
            cat > "$path" << 'EOF'
#!/bin/bash
# System Detection Utility

detect_system() {
    if [[ -f /etc/arch-release ]]; then
        SYSTEM="arch"
    elif [[ -f /etc/debian_version ]]; then
        SYSTEM="debian"
    else
        SYSTEM="unknown"
    fi
    export SYSTEM
    print_status "Detected system: $SYSTEM"
}
EOF
            ;;
        "user_interaction.sh")
            cat > "$path" << 'EOF'
#!/bin/bash
# User Interaction Utility

ask_yes_no() {
    local prompt=$1
    local default=${2:-n}
    
    if [[ "$AUTO_YES" == true ]]; then
        return 0
    fi
    
    local yn
    if [[ "$default" == "y" ]]; then
        read -p "$prompt [Y/n]: " yn
        yn=${yn:-y}
    else
        read -p "$prompt [y/N]: " yn
        yn=${yn:-n}
    fi
    
    [[ "$yn" =~ ^[Yy] ]]
}
EOF
            ;;
    esac
    chmod +x "$path"
}

create_placeholder_step() {
    local name=$1
    local path=$2
    
    case "$name" in
        "update_system.sh")
            cat > "$path" << 'EOF'
#!/bin/bash
# System Update Step

update_system() {
    print_status "Updating system packages..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN - Would update system packages"
        return 0
    fi
    
    if [[ "$SYSTEM" == "arch" ]]; then
        sudo pacman -Syu --noconfirm
    elif [[ "$SYSTEM" == "debian" ]]; then
        sudo apt update && sudo apt upgrade -y
    fi
    
    print_success "System updated"
}
EOF
            ;;
        "install_software.sh")
            cat > "$path" << 'EOF'
#!/bin/bash
# Software Installation Step

install_yay() {
    if [[ "$SYSTEM" != "arch" ]]; then
        return 0
    fi
    
    if command -v yay &> /dev/null; then
        print_success "yay is already installed"
        return 0
    fi
    
    print_status "Installing yay AUR helper..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN - Would install yay"
        return 0
    fi
    
    # Install dependencies
    sudo pacman -S --needed --noconfirm git base-devel
    
    # Clone and build yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay
    
    print_success "yay installed"
}
EOF
            ;;
        "install_fonts.sh")
            cat > "$path" << 'EOF'
#!/bin/bash
# Font Installation Step

install_nerd_font() {
    print_status "Installing Nerd Fonts..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN - Would install Nerd Fonts"
        return 0
    fi
    
    # Install font packages based on system
    if [[ "$SYSTEM" == "arch" ]]; then
        if command -v yay &> /dev/null; then
            yay -S --needed --noconfirm ttf-ubuntumono-nerd
        else
            print_warning "yay not available, skipping AUR fonts"
        fi
    elif [[ "$SYSTEM" == "debian" ]]; then
        # Download and install manually for Debian
        mkdir -p ~/.local/share/fonts
        cd /tmp
        wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/UbuntuMono.zip
        unzip -o UbuntuMono.zip -d ~/.local/share/fonts/
        fc-cache -fv
        cd -
    fi
    
    print_success "Fonts installed"
}
EOF
            ;;
        "configure_locale.sh")
            cat > "$path" << 'EOF'
#!/bin/bash
# Locale Configuration Step

configure_locale() {
    print_status "Configuring locale settings..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN - Would configure locale"
        return 0
    fi
    
    # Set locale to en_US.UTF-8
    if [[ "$SYSTEM" == "arch" ]]; then
        sudo sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
        sudo locale-gen
        sudo localectl set-locale LANG=en_US.UTF-8
    elif [[ "$SYSTEM" == "debian" ]]; then
        sudo locale-gen en_US.UTF-8
        sudo update-locale LANG=en_US.UTF-8
    fi
    
    print_success "Locale configured"
}
EOF
            ;;
    esac
    chmod +x "$path"
}

# Source all required files
source_files() {
    # Source utilities first
    for util in "$UTILS_PATH"/*.sh; do
        [[ -f "$util" ]] && source "$util"
    done
    
    # Source libraries
    for lib in "$LIB_PATH"/*.sh; do
        [[ -f "$lib" ]] && source "$lib"
    done
    
    # Source steps
    for step in "$STEPS_PATH"/*.sh; do
        [[ -f "$step" ]] && source "$step"
    done
}

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
    
    print_success "Packages installed"
}

# Deploy configuration files using config merger
deploy_configurations() {
    print_status "Deploying configuration files for device: $DEVICE_NAME"
    
    local configs=(
        "bashrc:$HOME/.bashrc"
        "bash_profile:$HOME/.bash_profile"
        "profile:$HOME/.profile"
        "bash_aliases:$HOME/.bash_aliases"
        "kitty.conf:$HOME/.config/kitty/kitty.conf"
        "i3/config:$HOME/.config/i3/config"
        "i3blocks/config:$HOME/.config/i3blocks/config"
        "i3status/config:$HOME/.config/i3status/config"
        "picom.conf:$HOME/.config/picom/picom.conf"
        "xinitrc:$HOME/.xinitrc"
        "kglobalshortcutsrc:$HOME/.config/kglobalshortcutsrc"
    )
    
    for config_pair in "${configs[@]}"; do
        IFS=':' read -r config_name target_path <<< "$config_pair"
        
        # Check if config exists for merging
        if ! config_exists_for_merge "$config_name" "$DEVICE_NAME"; then
            [[ "$VERBOSE" == true ]] && print_warning "No config found for: $config_name"
            continue
        fi
        
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
            [[ "$VERBOSE" == true ]] && print_status "Backup created: $backup_path"
        fi
        
        # Use config merger to handle the merge logic
        merge_configs "$config_name" "$DEVICE_NAME" "$target_path"
        
        # Process templates with device variables if device.conf exists
        if [[ -f "$CONFIG_PATH/devices/$DEVICE_NAME/device.conf" ]]; then
            process_template "$target_path" "$target_path" "$CONFIG_PATH/devices/$DEVICE_NAME/device.conf"
        fi
    done
    
    print_success "Configuration files deployed"
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
    
    # Check required files and create placeholders if needed
    check_required_files
    
    # Source all files
    source_files
    
    # Detect system type (after sourcing files)
    if command -v detect_system &> /dev/null; then
        detect_system
    else
        # Fallback if detect_system is not available
        if [[ -f /etc/arch-release ]]; then
            SYSTEM="arch"
        elif [[ -f /etc/debian_version ]]; then
            SYSTEM="debian"
        else
            SYSTEM="unknown"
        fi
        export SYSTEM
        print_status "Detected system: $SYSTEM"
    fi
    
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
    
    # Step 5: Deploy configurations using config merger
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
