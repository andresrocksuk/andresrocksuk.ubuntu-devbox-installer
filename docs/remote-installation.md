# Remote Installation

For quick and easy installation without cloning the repository, you can use the remote installation script:

# Remote Installation

For quick and easy installation without cloning the repository, you can use the remote installation scripts:

## Quick Start

### From Windows PowerShell (Recommended for WSL management):

```powershell
irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1" | iex
```

### From Linux/WSL Bash:

```bash
curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash
```

## Advanced Usage

### PowerShell Installation (Windows/WSL Management)

#### Installation supported parameters

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1"))) -Help
```

#### Installation with WSL Reset (⚠️ **WARNING**: This will delete existing WSL data)

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1"))) -ResetWSL
```

#### Installation with Custom Configuration

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

### Bash Installation (Linux/WSL Direct)

#### Show Help

```bash
curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash -s -- --help
```

#### Installation with Parameters

```bash
# Force reinstall everything
curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash -s -- --force

# Install only specific sections
curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash -s -- --sections "prerequisites,apt_packages"

# Use custom configuration from URL
curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash -s -- --config "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/refs/heads/main/examples/minimal-dev.yaml"

# Dry run to see what would be installed
curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash -s -- --dry-run

# Use development branch
curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/dev/install-remote.sh" | bash -s -- --branch "dev"

# Download script first, then run (alternative approach)
curl -sSL -o install-remote.sh "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh"
chmod +x install-remote.sh
./install-remote.sh --dry-run --sections "prerequisites,apt_packages"
```

### Show Help

#### PowerShell:
```powershell
irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1" | iex -Help
```

#### Bash:
```bash
curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash -s -- --help
```

## How It Works

### PowerShell Remote Installer (`install-wsl-remote.ps1`)

The PowerShell remote installation script:

1. Downloads the latest version from the specified branch (default: `main`)
2. Extracts it to a temporary directory
3. Executes `install-wsl.ps1` with the `-AutoInstall` flag and passed parameters
4. Cleans up temporary files after installation

### Bash Remote Installer (`install-remote.sh`)

The Bash remote installation script:

1. Downloads the latest version from the specified branch (default: `main`)
2. Extracts it to a temporary directory
3. Executes `src/install.sh` directly with the passed parameters
4. Cleans up temporary files after installation

## Requirements

### For PowerShell Installation
- PowerShell 5.1 or later
- Administrator privileges (for WSL management)
- Internet connection
- Windows 10 version 2004 or later (for WSL2)

### For Bash Installation
- Bash shell (Linux, WSL, macOS)
- curl or wget (usually pre-installed)
- unzip utility
- Internet connection

## Troubleshooting

If the remote installation fails:

### PowerShell Installation Issues
1. Check your internet connection
2. Ensure you're running PowerShell as Administrator
3. Try downloading and running the installer manually from the [releases page](https://github.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/releases)

### Bash Installation Issues
1. Check your internet connection
2. Ensure curl/wget and unzip are installed:
   ```bash
   # Ubuntu/Debian
   sudo apt update && sudo apt install curl unzip
   
   # CentOS/RHEL
   sudo yum install curl unzip
   
   # Alpine
   sudo apk add curl unzip
   ```
3. Try downloading the script first and running locally:
   ```bash
   curl -sSL -o install-remote.sh "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh"
   chmod +x install-remote.sh
   ./install-remote.sh --help
   ```
3. Try downloading and running the installer manually from the [releases page](https://github.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/releases)
