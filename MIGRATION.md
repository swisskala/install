# Migration Guide

## Migrating to the New Modular Structure

### Quick Start

1. **Backup your current configs**:
   ```bash
   mkdir -p ~/config-backup
   cp ~/.bashrc ~/.config/i3/config ~/.config/kitty/kitty.conf ~/config-backup/
   ```

2. **Copy your configs to the new structure**:
   - Put common settings in `config/global/*.global`
   - Put device-specific settings in `config/devices/[device]/*`

3. **Run the setup**:
   ```bash
   ./setup.sh --device [your-device]
   ```

### Configuration Structure

- **Global configs**: Shared across all devices
- **Device configs**: Override or extend global configs
- Device configs take priority when both exist

### Adding Custom Packages

Edit the package lists in `packages/`:
- `global.list` - packages for all systems
- `arch.list` or `debian.list` - distro-specific
- `devices/[device].list` - device-specific

### Device Configuration

Edit `config/devices/[device]/device.conf` to set:
- Font sizes
- Display settings
- Hardware-specific options
