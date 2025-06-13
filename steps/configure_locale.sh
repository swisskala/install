#!/bin/bash
# Locale Configuration Step

configure_locale() {
    print_status "Configuring locale settings..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN - Would configure locale"
        return 0
    fi
    
    case "$SYSTEM" in
        arch)
            # Enable en_US.UTF-8
            sudo sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
            sudo locale-gen
            
            # Set system locale
            echo "LANG=en_US.UTF-8" | sudo tee /etc/locale.conf
            
            # Set for current session
            export LANG=en_US.UTF-8
            export LC_ALL=en_US.UTF-8
            ;;
            
        debian)
            # Install locales package
            sudo apt install -y locales
            
            # Enable en_US.UTF-8
            sudo sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
            sudo locale-gen en_US.UTF-8
            
            # Update locale
            sudo update-locale LANG=en_US.UTF-8
            
            # Set for current session
            export LANG=en_US.UTF-8
            export LC_ALL=en_US.UTF-8
            ;;
            
        *)
            print_error "Unsupported system: $SYSTEM"
            return 1
            ;;
    esac
    
    print_success "Locale configured to en_US.UTF-8"
}
