#!/bin/bash
# Software Installation Step

# Install a single package with appropriate package manager
install_package() {
    local package=$1
    
    case "$SYSTEM" in
        arch)
            if command -v yay &> /dev/null; then
                yay -S --needed --noconfirm "$package"
            else
                sudo pacman -S --needed --noconfirm "$package"
            fi
            ;;
        debian)
            sudo apt install -y "$package"
            ;;
        *)
            print_error "Unsupported system: $SYSTEM"
            return 1
            ;;
    esac
}

# Install multiple packages
install_packages() {
    local packages=("$@")
    
    for package in "${packages[@]}"; do
        print_status "Installing: $package"
        if install_package "$package"; then
            print_success "$package installed"
        else
            print_warning "Failed to install: $package"
        fi
    done
}
