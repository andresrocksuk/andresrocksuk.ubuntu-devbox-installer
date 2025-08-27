# Remote Installation

For quick and easy installation without cloning the repository, you can use the remote installation script:

## Quick Start

```powershell
irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1" | iex
```

## Advanced Usage

### Installation with WSL Reset (⚠️ **WARNING**: This will delete existing WSL data)

```powershell
irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1" | iex -ResetWSL
```

### Installation with Custom Configuration

```powershell
# Minimal development environment
irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1" | iex -Config "minimal-dev"

# Data science environment
irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1" | iex -Config "data-science"
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
