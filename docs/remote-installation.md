# Remote Installation

For quick and easy installation without cloning the repository, you can use the remote installation script:

## Quick Start

```powershell
irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1" | iex
```

## Advanced Usage

### Installation supported parameters

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1"))) -Help
```

### Installation with WSL Reset (⚠️ **WARNING**: This will delete existing WSL data)

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1"))) -ResetWSL
```

### Installation with Custom Configuration

```powershell
# Installation without requiring confirmation
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1"))) -Force

# Minimal development environment (specific sections)
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1"))) -Sections @("prerequisites","apt_packages")

# Custom configuration file from URL
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1"))) -Config "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/refs/heads/main/src/install.yaml"

# Combine custom config with specific sections
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1"))) -Config "https://raw.githubusercontent.com/username/repo/main/config.yaml" -Sections @("custom_software")
```

### Show Help

```powershell
irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1" | iex -Help
```

## How It Works

The remote installation script:

1. Downloads the latest version from the `main` branch
2. Extracts it to a temporary directory
3. Executes `install-wsl.ps1` with the `-AutoInstall` flag
4. Cleans up temporary files after installation

## Requirements

- PowerShell 5.1 or later
- Administrator privileges
- Internet connection
- Windows 10 version 2004 or later (for WSL2)

## Troubleshooting

If the remote installation fails:

1. Check your internet connection
2. Ensure you're running PowerShell as Administrator
3. Try downloading and running the installer manually from the [releases page](https://github.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/releases)
