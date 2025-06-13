#!/bin/bash
# System Update Step

update_system() {
    print_status "Updating system packages..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN - Would update system packages"
        return 0
    fi
    
    case "$SYSTEM" in
        arch)
            sudo pacman -Syu --noconfirm
            ;;
        debian)
            sudo apt update && sudo apt upgrade -y
            ;;
        *)
            print_error "Unsupported system: $SYSTEM"
            return 1
            ;;
    esac
    
    print_success "System updated"
}
