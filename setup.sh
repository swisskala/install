#!/bin/bash
# Modular System Setup Script
# Supports multiple devices with global and device-specific configurations

set -euo pipefail

# Script paths
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
SYSTEM=""

# Source all required files
source_all() {
  local dirs=("$UTILS_PATH" "$LIB_PATH" "$STEPS_PATH")
  for dir in "${dirs[@]}"; do
    for file in "$dir"/*.sh; do
      [[ -f "$file" ]] && source "$file"
    done
  done
}

# Show usage
usage() {
  cat <<EOF
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
    --yes | -y)
      AUTO_YES=true
      shift
      ;;
    --help | -h) usage ;;
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
      list_device_configs
      read -p "Please enter device name: " DEVICE_NAME
    fi
  fi

  if [[ ! -d "$CONFIG_PATH/devices/$DEVICE_NAME" ]]; then
    print_error "Device configuration not found: $CONFIG_PATH/devices/$DEVICE_NAME"
    list_device_configs
    exit 1
  fi

  if [[ -f "$CONFIG_PATH/devices/$DEVICE_NAME/device.conf" ]]; then
    print_status "Loading device configuration for: $DEVICE_NAME"
    source "$CONFIG_PATH/devices/$DEVICE_NAME/device.conf"
    print_success "Device configuration loaded"
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
    ask_yes_no "Do you want to proceed with this setup?" || exit 0
  fi
}

# Install packages from lists
install_from_lists() {
  local lists=(
    "$PACKAGES_PATH/global.list"
    "$PACKAGES_PATH/$SYSTEM.list"
    "$PACKAGES_PATH/devices/$DEVICE_NAME.list"
  )

  local packages=()
  for list in "${lists[@]}"; do
    [[ -f "$list" ]] || continue
    while IFS= read -r line; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      packages+=("$(echo "$line" | xargs)")
    done <"$list"
  done

  # Remove duplicates
  local unique_packages=($(printf '%s\n' "${packages[@]}" | sort -u))

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

  # Use package manager library
  if command -v install_packages_batch &>/dev/null; then
    install_packages_batch "${unique_packages[@]}"
  else
    # Fallback
    case "$SYSTEM" in
    arch)
      if command -v yay &>/dev/null; then
        yay -S --needed --noconfirm "${unique_packages[@]}"
      else
        sudo pacman -S --needed --noconfirm "${unique_packages[@]}"
      fi
      ;;
    debian)
      sudo apt install -y "${unique_packages[@]}"
      ;;
    esac
  fi
}

# Main execution
main() {
  echo "========================================="
  echo "    Modular System Setup Script"
  echo "========================================="
  echo

  # Source all files
  source_all

  # Detect system
  detect_system

  # Setup device
  setup_device

  # Show plan
  show_setup_plan

  # Execute steps
  [[ "$SKIP_PACKAGES" != true ]] && {
    update_system
    [[ "$SYSTEM" == "arch" ]] && install_yay
    install_from_lists
  }

  [[ "$SKIP_FONTS" != true ]] && install_nerd_font
  [[ "$SKIP_CONFIGS" != true ]] && configure_dotfiles
  [[ "$SKIP_LOCALE" != true ]] && configure_locale

  # Summary
  echo
  print_success "Setup completed successfully!"
  echo
  print_status "Post-setup notes:"
  echo "  • Run 'source ~/.bashrc' to reload shell configuration"
  echo "  • Restart your terminal for font changes to take effect"
  echo "  • Log out and back in for all changes to take full effect"

  [[ "$DRY_RUN" == true ]] && {
    echo
    print_warning "This was a DRY RUN - no changes were made"
  }
}

# Parse arguments and run
parse_arguments "$@"
main "$@"
