#!/bin/bash
# Yay Installation Step (Arch Linux AUR Helper)

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
    local temp_dir="/tmp/yay-install-$$"
    git clone https://aur.archlinux.org/yay.git "$temp_dir"
    cd "$temp_dir"
    makepkg -si --noconfirm
    cd -
    rm -rf "$temp_dir"
    
    print_success "yay installed"
}
