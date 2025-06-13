#!/bin/bash
# Dotfiles Configuration Step
# Handles deployment of configuration files using the config merger

# Main function to configure all dotfiles
configure_dotfiles() {
    print_status "Configuring dotfiles for device: $DEVICE_NAME"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN - Would deploy configuration files"
        list_configs_to_deploy
        return 0
    fi
    
    # Deploy all configuration files
    deploy_all_configs
    
    # Deploy system scripts
    deploy_system_scripts
    
    print_success "Dotfiles configuration completed"
}

# List configurations that would be deployed
list_configs_to_deploy() {
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
    
    echo "Configurations to deploy:"
    for config_pair in "${configs[@]}"; do
        IFS=':' read -r config_name target_path <<< "$config_pair"
        if config_exists_for_merge "$config_name" "$DEVICE_NAME"; then
            echo "  ✓ $config_name → $target_path"
        else
            echo "  ✗ $config_name (not found)"
        fi
    done
}

# Deploy all configuration files
deploy_all_configs() {
    # Define all configurations to deploy
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
    
    # Process each configuration
    for config_pair in "${configs[@]}"; do
        IFS=':' read -r config_name target_path <<< "$config_pair"
        deploy_single_config "$config_name" "$target_path"
    done
}

# Deploy a single configuration file
deploy_single_config() {
    local config_name=$1
    local target_path=$2
    
    # Check if config exists for merging
    if ! config_exists_for_merge "$config_name" "$DEVICE_NAME"; then
        [[ "$VERBOSE" == true ]] && print_warning "No config found for: $config_name"
        return 1
    fi
    
    print_status "Deploying: $config_name"
    
    # Create target directory if needed
    local target_dir=$(dirname "$target_path")
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
        [[ "$VERBOSE" == true ]] && print_status "Created directory: $target_dir"
    fi
    
    # Backup existing file if it exists
    if [[ -f "$target_path" ]]; then
        create_backup "$target_path"
    fi
    
    # Use config merger to handle the merge logic
    if merge_configs "$config_name" "$DEVICE_NAME" "$target_path"; then
        # Process templates with device variables if device.conf exists
        if [[ -f "$CONFIG_PATH/devices/$DEVICE_NAME/device.conf" ]]; then
            process_template "$target_path" "$target_path" "$CONFIG_PATH/devices/$DEVICE_NAME/device.conf"
        fi
        
        # Set appropriate permissions
        set_config_permissions "$target_path"
        
        [[ "$VERBOSE" == true ]] && print_success "Deployed: $target_path"
    else
        print_error "Failed to deploy: $config_name"
        return 1
    fi
}

# Create backup of existing file
create_backup() {
    local file=$1
    local backup_dir="$HOME/.config-backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local relative_path=${file#$HOME/}
    local backup_path="$backup_dir/${relative_path}.${timestamp}"
    
    # Create backup directory structure
    mkdir -p "$(dirname "$backup_path")"
    
    # Copy file to backup location
    cp "$file" "$backup_path"
    
    if [[ "$VERBOSE" == true ]]; then
        print_status "Backup created: $backup_path"
    else
        print_status "Backup created for: $(basename "$file")"
    fi
}

# Set appropriate permissions for config files
set_config_permissions() {
    local file=$1
    local basename=$(basename "$file")
    
    case "$basename" in
        .bashrc|.bash_profile|.profile|.xinitrc)
            chmod 644 "$file"
            ;;
        config|*.conf)
            chmod 644 "$file"
            ;;
        *)
            chmod 644 "$file"
            ;;
    esac
}

# Deploy system scripts (like llm-remote)
deploy_system_scripts() {
    print_status "Deploying system scripts..."
    
    # Check for llm-remote script
    local llm_script="$SCRIPTS_PATH/llm-remote-$SYSTEM"
    if [[ -f "$llm_script" ]]; then
        deploy_llm_remote "$llm_script"
    fi
    
    # Deploy any other scripts in the scripts directory
    deploy_other_scripts
}

# Deploy llm-remote script
deploy_llm_remote() {
    local script_path=$1
    local target_path="/usr/local/bin/llm-remote"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN - Would install llm-remote to $target_path"
        return 0
    fi
    
    if [[ "$AUTO_YES" == true ]] || ask_yes_no "Install llm-remote script?"; then
        # Backup existing if present
        if [[ -f "$target_path" ]]; then
            sudo cp "$target_path" "${target_path}.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Copy and set permissions
        sudo cp "$script_path" "$target_path"
        sudo chmod +x "$target_path"
        sudo chown root:root "$target_path"
        
        print_success "llm-remote script installed to $target_path"
    else
        print_status "Skipped llm-remote installation"
    fi
}

# Deploy other scripts from scripts directory
deploy_other_scripts() {
    # Look for any executable scripts that should be deployed
    for script in "$SCRIPTS_PATH"/*; do
        [[ ! -f "$script" ]] && continue
        [[ ! -x "$script" ]] && continue
        
        local script_name=$(basename "$script")
        
        # Skip system-specific variants
        [[ "$script_name" =~ -arch$ ]] && [[ "$SYSTEM" != "arch" ]] && continue
        [[ "$script_name" =~ -debian$ ]] && [[ "$SYSTEM" != "debian" ]] && continue
        
        # Skip if already processed
        [[ "$script_name" =~ ^llm-remote- ]] && continue
        
        # Ask to deploy
        if [[ "$AUTO_YES" == true ]] || ask_yes_no "Install $script_name to /usr/local/bin?"; then
            sudo cp "$script" "/usr/local/bin/$script_name"
            sudo chmod +x "/usr/local/bin/$script_name"
            print_success "$script_name installed"
        fi
    done
}

# Restore dotfiles from backup
restore_dotfiles() {
    local backup_dir="$HOME/.config-backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        print_error "No backup directory found at: $backup_dir"
        return 1
    fi
    
    print_status "Available backups:"
    find "$backup_dir" -type f -name "*.backup.*" | sort -r | head -20
    
    echo ""
    local backup_file
    read -p "Enter the full path of the backup to restore (or 'cancel'): " backup_file
    
    if [[ "$backup_file" == "cancel" ]]; then
        print_status "Restore cancelled"
        return 0
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Determine target path from backup path
    local relative_path=$(echo "$backup_file" | sed -E 's|.*/\.config-backups/||; s|\.[0-9]{8}_[0-9]{6}$||')
    local target_path="$HOME/$relative_path"
    
    if ask_yes_no "Restore $backup_file to $target_path?"; then
        cp "$backup_file" "$target_path"
        print_success "Restored: $target_path"
    fi
}

# Show dotfiles status
show_dotfiles_status() {
    print_status "Dotfiles status for device: $DEVICE_NAME"
    echo ""
    
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
        
        echo -n "$config_name: "
        
        if [[ -f "$target_path" ]]; then
            echo -n "✓ Deployed"
            
            # Check if it's been modified
            if [[ -f "$HOME/.config-backups/${target_path#$HOME/}".* ]]; then
                echo " (has backups)"
            else
                echo " (no backups)"
            fi
        else
            echo "✗ Not deployed"
        fi
    done
}

# Clean old backups
clean_old_backups() {
    local backup_dir="$HOME/.config-backups"
    local days=${1:-30}
    
    if [[ ! -d "$backup_dir" ]]; then
        print_status "No backup directory found"
        return 0
    fi
    
    print_status "Cleaning backups older than $days days..."
    
    local count=$(find "$backup_dir" -type f -mtime +$days | wc -l)
    
    if [[ $count -eq 0 ]]; then
        print_status "No old backups found"
        return 0
    fi
    
    print_warning "Found $count backups older than $days days"
    
    if ask_yes_no "Delete these old backups?"; then
        find "$backup_dir" -type f -mtime +$days -delete
        print_success "Old backups cleaned"
    fi
}
