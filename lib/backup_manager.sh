#!/bin/bash
# Backup Manager Library
# Handles backup and restore operations for configuration files

# Default backup directory
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/.config-backups}"
BACKUP_MANIFEST="$BACKUP_ROOT/.manifest"

# Initialize backup system
init_backup_system() {
    if [[ ! -d "$BACKUP_ROOT" ]]; then
        mkdir -p "$BACKUP_ROOT"
        print_status "Created backup directory: $BACKUP_ROOT"
    fi
    
    # Create manifest file if it doesn't exist
    if [[ ! -f "$BACKUP_MANIFEST" ]]; then
        echo "# Backup Manifest - Created $(date)" > "$BACKUP_MANIFEST"
        echo "# Format: timestamp|file|backup_path|checksum" >> "$BACKUP_MANIFEST"
    fi
}

# Create a backup of a file
# Usage: create_backup "file_path" ["description"]
create_backup() {
    local file_path=$1
    local description=${2:-"Manual backup"}
    
    if [[ ! -f "$file_path" ]]; then
        print_error "File not found: $file_path"
        return 1
    fi
    
    # Initialize if needed
    init_backup_system
    
    # Generate backup path
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local relative_path=${file_path#$HOME/}
    local backup_path="$BACKUP_ROOT/${relative_path}.${timestamp}"
    
    # Create backup directory structure
    mkdir -p "$(dirname "$backup_path")"
    
    # Copy file to backup location
    if cp -p "$file_path" "$backup_path"; then
        # Calculate checksum
        local checksum=$(calculate_checksum "$file_path")
        
        # Add to manifest
        echo "${timestamp}|${file_path}|${backup_path}|${checksum}|${description}" >> "$BACKUP_MANIFEST"
        
        if [[ "$VERBOSE" == true ]]; then
            print_success "Backup created: $backup_path"
        else
            print_success "Backed up: $(basename "$file_path")"
        fi
        
        echo "$backup_path"
        return 0
    else
        print_error "Failed to create backup"
        return 1
    fi
}

# Create backups of multiple files
# Usage: create_backups_batch file1 file2 file3...
create_backups_batch() {
    local files=("$@")
    local failed=0
    
    print_status "Creating backups for ${#files[@]} files..."
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            create_backup "$file" "Batch backup" >/dev/null || ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        print_success "All backups created successfully"
    else
        print_warning "$failed backups failed"
    fi
}

# List available backups
# Usage: list_backups ["file_path"]
list_backups() {
    local file_filter=${1:-""}
    
    if [[ ! -f "$BACKUP_MANIFEST" ]]; then
        print_warning "No backups found"
        return 1
    fi
    
    print_status "Available backups:"
    echo ""
    
    # Read manifest and display backups
    local count=0
    while IFS='|' read -r timestamp file backup_path checksum description; do
        # Skip comments and empty lines
        [[ "$timestamp" =~ ^#.*$ ]] || [[ -z "$timestamp" ]] && continue
        
        # Apply filter if provided
        if [[ -n "$file_filter" ]] && [[ "$file" != "$file_filter" ]]; then
            continue
        fi
        
        if [[ -f "$backup_path" ]]; then
            local date_formatted=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp")
            echo "  [$((++count))] $date_formatted - $(basename "$file")"
            echo "      Path: $file"
            echo "      Backup: $backup_path"
            [[ -n "$description" ]] && echo "      Note: $description"
            echo ""
        fi
    done < "$BACKUP_MANIFEST"
    
    if [[ $count -eq 0 ]]; then
        print_warning "No backups found for: ${file_filter:-all files}"
    else
        echo "Total backups: $count"
    fi
}

# Restore a backup
# Usage: restore_backup "backup_path" ["target_path"]
restore_backup() {
    local backup_path=$1
    local target_path=${2:-""}
    
    if [[ ! -f "$backup_path" ]]; then
        print_error "Backup file not found: $backup_path"
        return 1
    fi
    
    # If target not specified, try to determine from manifest
    if [[ -z "$target_path" ]]; then
        target_path=$(grep "$backup_path" "$BACKUP_MANIFEST" 2>/dev/null | cut -d'|' -f2 | head -1)
        
        if [[ -z "$target_path" ]]; then
            print_error "Could not determine target path. Please specify target."
            return 1
        fi
    fi
    
    print_status "Restoring backup:"
    echo "  From: $backup_path"
    echo "  To: $target_path"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN - Would restore file"
        return 0
    fi
    
    # Create backup of current file if it exists
    if [[ -f "$target_path" ]]; then
        print_status "Backing up current file before restore..."
        create_backup "$target_path" "Pre-restore backup" >/dev/null
    fi
    
    # Restore the file
    if cp -p "$backup_path" "$target_path"; then
        print_success "File restored successfully"
        
        # Log the restore
        echo "$(date +%Y%m%d_%H%M%S)|RESTORE|$backup_path|$target_path" >> "$BACKUP_MANIFEST"
        return 0
    else
        print_error "Failed to restore file"
        return 1
    fi
}

# Interactive restore
# Usage: restore_interactive ["file_path"]
restore_interactive() {
    local file_filter=${1:-""}
    
    # List available backups
    list_backups "$file_filter"
    
    echo ""
    read -p "Enter backup number to restore (or 'q' to quit): " choice
    
    [[ "$choice" == "q" ]] && return 0
    
    # Validate choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
        print_error "Invalid choice"
        return 1
    fi
    
    # Find the backup from manifest
    local count=0
    local found=false
    while IFS='|' read -r timestamp file backup_path checksum description; do
        [[ "$timestamp" =~ ^#.*$ ]] || [[ -z "$timestamp" ]] && continue
        [[ -n "$file_filter" ]] && [[ "$file" != "$file_filter" ]] && continue
        
        if [[ -f "$backup_path" ]]; then
            ((count++))
            if [[ $count -eq $choice ]]; then
                found=true
                if ask_yes_no "Restore this backup?"; then
                    restore_backup "$backup_path" "$file"
                fi
                break
            fi
        fi
    done < "$BACKUP_MANIFEST"
    
    if [[ "$found" != true ]]; then
        print_error "Invalid selection"
        return 1
    fi
}

# Calculate file checksum
calculate_checksum() {
    local file=$1
    
    if command -v sha256sum &> /dev/null; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum &> /dev/null; then
        shasum -a 256 "$file" | cut -d' ' -f1
    elif command -v md5sum &> /dev/null; then
        md5sum "$file" | cut -d' ' -f1
    else
        echo "no-checksum-available"
    fi
}

# Verify backup integrity
# Usage: verify_backup "backup_path"
verify_backup() {
    local backup_path=$1
    
    if [[ ! -f "$backup_path" ]]; then
        print_error "Backup not found: $backup_path"
        return 1
    fi
    
    # Get stored checksum from manifest
    local stored_checksum=$(grep "$backup_path" "$BACKUP_MANIFEST" 2>/dev/null | cut -d'|' -f4 | head -1)
    
    if [[ -z "$stored_checksum" ]] || [[ "$stored_checksum" == "no-checksum-available" ]]; then
        print_warning "No checksum available for verification"
        return 0
    fi
    
    # Calculate current checksum
    local current_checksum=$(calculate_checksum "$backup_path")
    
    if [[ "$stored_checksum" == "$current_checksum" ]]; then
        print_success "Backup integrity verified"
        return 0
    else
        print_error "Backup integrity check failed!"
        return 1
    fi
}

# Clean old backups
# Usage: clean_old_backups [days]
clean_old_backups() {
    local days=${1:-30}
    local dry_run=${2:-false}
    
    print_status "Searching for backups older than $days days..."
    
    local count=0
    local size=0
    
    # Find old backup files
    while IFS= read -r -d '' file; do
        local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
        ((count++))
        ((size += file_size))
        
        if [[ "$VERBOSE" == true ]]; then
            echo "  - $file ($(numfmt --to=iec --suffix=B $file_size 2>/dev/null || echo "${file_size}B"))"
        fi
        
        if [[ "$dry_run" != true ]] && [[ "$DRY_RUN" != true ]]; then
            rm -f "$file"
        fi
    done < <(find "$BACKUP_ROOT" -type f -name "*.backup.*" -mtime +$days -print0 2>/dev/null)
    
    if [[ $count -eq 0 ]]; then
        print_status "No old backups found"
    else
        local size_human=$(numfmt --to=iec --suffix=B $size 2>/dev/null || echo "${size}B")
        
        if [[ "$dry_run" == true ]] || [[ "$DRY_RUN" == true ]]; then
            print_status "Would remove $count old backups ($size_human)"
        else
            print_success "Removed $count old backups ($size_human)"
            
            # Clean up manifest
            cleanup_manifest
        fi
    fi
}

# Clean up manifest file
cleanup_manifest() {
    local temp_manifest="${BACKUP_MANIFEST}.tmp"
    
    # Keep only entries for existing backups
    {
        grep "^#" "$BACKUP_MANIFEST" 2>/dev/null || echo "# Backup Manifest"
        while IFS='|' read -r timestamp file backup_path checksum description; do
            [[ "$timestamp" =~ ^#.*$ ]] || [[ -z "$timestamp" ]] && continue
            
            if [[ -f "$backup_path" ]]; then
                echo "${timestamp}|${file}|${backup_path}|${checksum}|${description}"
            fi
        done < "$BACKUP_MANIFEST"
    } > "$temp_manifest"
    
    mv "$temp_manifest" "$BACKUP_MANIFEST"
}

# Get backup statistics
backup_stats() {
    if [[ ! -d "$BACKUP_ROOT" ]]; then
        print_warning "No backup directory found"
        return 1
    fi
    
    print_status "Backup Statistics"
    echo "================="
    
    # Count backups
    local total_backups=$(find "$BACKUP_ROOT" -type f -name "*.backup.*" 2>/dev/null | wc -l)
    local total_size=$(du -sb "$BACKUP_ROOT" 2>/dev/null | cut -f1)
    local total_size_human=$(numfmt --to=iec --suffix=B $total_size 2>/dev/null || echo "${total_size}B")
    
    echo "Backup directory: $BACKUP_ROOT"
    echo "Total backups: $total_backups"
    echo "Total size: $total_size_human"
    echo ""
    
    # Show backups by config type
    print_status "Backups by configuration:"
    for config in bashrc profile kitty.conf picom.conf xinitrc; do
        local count=$(find "$BACKUP_ROOT" -name "*${config}.*" -type f 2>/dev/null | wc -l)
        [[ $count -gt 0 ]] && echo "  $config: $count backups"
    done
    
    # Show recent backups
    echo ""
    print_status "Recent backups (last 5):"
    find "$BACKUP_ROOT" -type f -name "*.backup.*" -printf "%T@ %p\n" 2>/dev/null | \
        sort -rn | head -5 | while read -r timestamp path; do
        echo "  - $(basename "$path")"
    done
}

# Export/Import backups
export_backups() {
    local export_file=${1:-"dotfiles-backups-$(date +%Y%m%d).tar.gz"}
    
    print_status "Exporting backups to: $export_file"
    
    if tar -czf "$export_file" -C "$HOME" ".config-backups" 2>/dev/null; then
        print_success "Backups exported successfully"
        print_status "Export file: $export_file ($(du -h "$export_file" | cut -f1))"
    else
        print_error "Failed to export backups"
        return 1
    fi
}

import_backups() {
    local import_file=$1
    
    if [[ ! -f "$import_file" ]]; then
        print_error "Import file not found: $import_file"
        return 1
    fi
    
    print_status "Importing backups from: $import_file"
    
    if tar -xzf "$import_file" -C "$HOME" 2>/dev/null; then
        print_success "Backups imported successfully"
        backup_stats
    else
        print_error "Failed to import backups"
        return 1
    fi
}
