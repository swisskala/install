# Optimized Setup Script

A modular system setup script with support for multiple devices and configurations.

## Structure

- `config/global/` - Shared configurations for all devices
- `config/devices/` - Device-specific configurations
- `lib/` - Library functions for the setup system
- `packages/` - Package lists (global, distro-specific, device-specific)
- `steps/` - Installation step scripts
- `utils/` - Utility functions

## Usage

```bash
./setup.sh                    # Auto-detect device and run full setup
./setup.sh --device surfarch  # Specify device manually
./setup.sh --dry-run         # Test without making changes
./setup.sh --skip-packages   # Skip package installation
./setup.sh --skip-configs    # Skip configuration files
```

## Adding a New Device

1. Create directory: `config/devices/newdevice/`
2. Create `device.conf` with device-specific variables
3. Add any device-specific config overrides
4. Create package list: `packages/devices/newdevice.list`
