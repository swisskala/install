#!/bin/bash
# Font Installation Step

install_nerd_font() {
    print_status "Installing Nerd Fonts..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN - Would install Nerd Fonts"
        return 0
    fi
    
    # Check if font is already installed
    if fc-list | grep -qi "ubuntumono.*nerd"; then
        print_success "UbuntuMono Nerd Font already installed"
        return 0
    fi
    
    case "$SYSTEM" in
        arch)
            if command -v yay &> /dev/null; then
                yay -S --needed --noconfirm ttf-ubuntumono-nerd
            else
                # Fallback to manual installation
                install_nerd_font_manual
            fi
            ;;
        debian)
            install_nerd_font_manual
            ;;
        *)
            print_error "Unsupported system: $SYSTEM"
            return 1
            ;;
    esac
    
    # Update font cache
    fc-cache -fv
    print_success "Font cache updated"
}

install_nerd_font_manual() {
    print_status "Installing Nerd Font manually..."
    
    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"
    
    cd /tmp
    wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/UbuntuMono.zip
    unzip -q -o UbuntuMono.zip -d "$font_dir/"
    rm UbuntuMono.zip
    cd -
    
    print_success "Nerd Font installed manually"
}
