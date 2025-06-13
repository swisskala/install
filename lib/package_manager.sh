#!/bin/bash
# Package Manager Library
# Handles package installation across different systems

# Detect package manager
detect_package_manager() {
    if command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        AUR_HELPER=""
        
        # Check for AUR helpers
        if command -v yay &> /dev/null; then
            AUR_HELPER="yay"
        elif command -v paru &> /dev/null; then
            AUR_HELPER="paru"
        elif command -v trizen &> /dev/null; then
            AUR_HELPER="trizen"
        fi
        
    elif command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
    else
        PKG_MANAGER="unknown"
    fi
    
    export PKG_MANAGER
    export AUR_HELPER
    
    if [[ "$VERBOSE" == true ]]; then
        print_status "Package manager: $PKG_MANAGER"
        [[ -n "$AUR_HELPER" ]] && print_status "AUR helper: $AUR_HELPER"
    fi
}

# Update package database
update_package_db() {
    print_status "Updating package database..."
    
    case "$PKG_MANAGER" in
        pacman)
            sudo pacman -Sy
            ;;
        apt)
            sudo apt update
            ;;
        dnf|yum)
            sudo $PKG_MANAGER check-update || true
            ;;
        zypper)
            sudo zypper refresh
            ;;
        *)
            print_error "Unknown package manager: $PKG_MANAGER"
            return 1
            ;;
    esac
}

# Install a single package
install_single_package() {
    local package=$1
    local use_aur=${2:-true}
    
    case "$PKG_MANAGER" in
        pacman)
            # Try official repos first
            if sudo pacman -S --needed --noconfirm "$package" 2>/dev/null; then
                return 0
            elif [[ "$use_aur" == true ]] && [[ -n "$AUR_HELPER" ]]; then
                # Try AUR if available
                $AUR_HELPER -S --needed --noconfirm "$package"
                return $?
            else
                return 1
            fi
            ;;
        apt)
            sudo apt install -y "$package"
            ;;
        dnf|yum)
            sudo $PKG_MANAGER install -y "$package"
            ;;
        zypper)
            sudo zypper install -y "$package"
            ;;
        *)
            print_error "Unknown package manager: $PKG_MANAGER"
            return 1
            ;;
    esac
}

# Install multiple packages at once (more efficient)
install_packages_batch() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi
    
    print_status "Installing ${#packages[@]} packages..."
    
    case "$PKG_MANAGER" in
        pacman)
            # Separate official and AUR packages
            local official_packages=()
            local aur_packages=()
            
            for package in "${packages[@]}"; do
                if pacman -Si "$package" &>/dev/null; then
                    official_packages+=("$package")
                else
                    aur_packages+=("$package")
                fi
            done
            
            # Install official packages
            if [[ ${#official_packages[@]} -gt 0 ]]; then
                print_status "Installing from official repositories..."
                sudo pacman -S --needed --noconfirm "${official_packages[@]}"
            fi
            
            # Install AUR packages
            if [[ ${#aur_packages[@]} -gt 0 ]] && [[ -n "$AUR_HELPER" ]]; then
                print_status "Installing from AUR..."
                $AUR_HELPER -S --needed --noconfirm "${aur_packages[@]}"
            fi
            ;;
            
        apt)
            sudo apt install -y "${packages[@]}"
            ;;
            
        dnf|yum)
            sudo $PKG_MANAGER install -y "${packages[@]}"
            ;;
            
        zypper)
            sudo zypper install -y "${packages[@]}"
            ;;
            
        *)
            print_error "Unknown package manager: $PKG_MANAGER"
            return 1
            ;;
    esac
}

# Check if package is installed
is_package_installed() {
    local package=$1
    
    case "$PKG_MANAGER" in
        pacman)
            pacman -Q "$package" &>/dev/null
            ;;
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        dnf|yum)
            rpm -q "$package" &>/dev/null
            ;;
        zypper)
            rpm -q "$package" &>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# Remove package
remove_package() {
    local package=$1
    
    case "$PKG_MANAGER" in
        pacman)
            sudo pacman -Rns --noconfirm "$package"
            ;;
        apt)
            sudo apt remove -y "$package"
            ;;
        dnf|yum)
            sudo $PKG_MANAGER remove -y "$package"
            ;;
        zypper)
            sudo zypper remove -y "$package"
            ;;
        *)
            print_error "Unknown package manager: $PKG_MANAGER"
            return 1
            ;;
    esac
}

# Clean package cache
clean_package_cache() {
    print_status "Cleaning package cache..."
    
    case "$PKG_MANAGER" in
        pacman)
            sudo pacman -Sc --noconfirm
            ;;
        apt)
            sudo apt clean
            sudo apt autoclean
            ;;
        dnf|yum)
            sudo $PKG_MANAGER clean all
            ;;
        zypper)
            sudo zypper clean
            ;;
        *)
            print_warning "Unknown package manager: $PKG_MANAGER"
            ;;
    esac
}

# Get package info
get_package_info() {
    local package=$1
    
    case "$PKG_MANAGER" in
        pacman)
            pacman -Si "$package" 2>/dev/null || pacman -Qi "$package" 2>/dev/null
            ;;
        apt)
            apt show "$package" 2>/dev/null
            ;;
        dnf|yum)
            $PKG_MANAGER info "$package" 2>/dev/null
            ;;
        zypper)
            zypper info "$package" 2>/dev/null
            ;;
        *)
            print_error "Unknown package manager: $PKG_MANAGER"
            return 1
            ;;
    esac
}

# Search for packages
search_packages() {
    local query=$1
    
    case "$PKG_MANAGER" in
        pacman)
            pacman -Ss "$query"
            [[ -n "$AUR_HELPER" ]] && $AUR_HELPER -Ss "$query"
            ;;
        apt)
            apt search "$query"
            ;;
        dnf|yum)
            $PKG_MANAGER search "$query"
            ;;
        zypper)
            zypper search "$query"
            ;;
        *)
            print_error "Unknown package manager: $PKG_MANAGER"
            return 1
            ;;
    esac
}

# Install packages from a list file
install_from_list_file() {
    local list_file=$1
    
    if [[ ! -f "$list_file" ]]; then
        print_error "Package list file not found: $list_file"
        return 1
    fi
    
    local packages=()
    
    # Read packages from file
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Remove inline comments and trim whitespace
        package=$(echo "$line" | sed 's/#.*//' | xargs)
        [[ -n "$package" ]] && packages+=("$package")
    done < "$list_file"
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        print_warning "No packages found in $list_file"
        return 0
    fi
    
    print_status "Found ${#packages[@]} packages in $list_file"
    install_packages_batch "${packages[@]}"
}

# Initialize package manager on script start
detect_package_manager
