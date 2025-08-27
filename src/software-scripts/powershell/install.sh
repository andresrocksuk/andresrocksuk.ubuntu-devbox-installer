#!/bin/bash

# PowerShell Core Installation Script
# This script installs the latest PowerShell Core

set -e

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WSL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities if available (for integration with main installer)
if [ -f "$WSL_DIR/utils/logger.sh" ]; then
    source "$WSL_DIR/utils/logger.sh"
else
    # Standalone logging functions
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_debug() { echo "[DEBUG] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
fi

# Standalone execution support
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    log_info "Running PowerShell installation script in standalone mode"
fi

# Check if PowerShell is already installed
if command -v pwsh >/dev/null 2>&1; then
    current_version=$(pwsh -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
    log_info "PowerShell is already installed (version: $current_version)"
    
    # Get latest version from GitHub API
    log_info "Checking for latest PowerShell version..."
    latest_version=$(curl -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4 | cut -d'v' -f2)
    
    if [ "$current_version" = "$latest_version" ]; then
        log_success "PowerShell is already up to date (version: $current_version)"
        exit 0
    else
        log_info "Newer version available: $latest_version (current: $current_version)"
        log_info "Proceeding with update..."
    fi
fi

log_info "Installing PowerShell Core..."

# Check if running on supported OS
if ! grep -q "Ubuntu\|Debian" /etc/os-release; then
    log_error "This script is designed for Ubuntu/Debian systems"
    exit 1
fi

# Install prerequisites
log_info "Installing prerequisites..."
sudo apt-get update >/dev/null 2>&1
sudo apt-get install -y wget apt-transport-https software-properties-common >/dev/null 2>&1

# Get Ubuntu version
ubuntu_version=$(lsb_release -rs)
log_info "Detected Ubuntu version: $ubuntu_version"

# Download Microsoft package signing key and add repository
log_info "Adding Microsoft repository..."
wget -q "https://packages.microsoft.com/config/ubuntu/$ubuntu_version/packages-microsoft-prod.deb"
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# Update package list
log_info "Updating package lists..."
sudo apt-get update >/dev/null 2>&1

# Install PowerShell
log_info "Installing PowerShell..."
sudo apt-get install -y powershell >/dev/null 2>&1

# Verify installation
if command -v pwsh >/dev/null 2>&1; then
    version=$(pwsh -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)
    log_success "PowerShell installed successfully (version: $version)"
    
    # Set up PowerShell profile directory
    log_info "Setting up PowerShell profile directory..."
    pwsh -c 'if (!(Test-Path $PROFILE)) { New-Item -Path $PROFILE -Type File -Force | Out-Null }' 2>/dev/null
    
    # Show basic usage info
    log_info ""
    log_info "To get started with PowerShell:"
    log_info "  pwsh                        # Start PowerShell"
    log_info "  pwsh -c 'Get-Help'          # Show help system"
    log_info "  pwsh -c 'Get-Command'       # List available commands"
    log_info "  pwsh -c 'Update-Help'       # Update help system"
    log_info ""
    log_info "PowerShell profile location:"
    profile_path=$(pwsh -c 'echo $PROFILE' 2>/dev/null)
    log_info "  $profile_path"
    log_info ""
    log_info "Documentation: https://docs.microsoft.com/powershell/"
else
    log_error "PowerShell installation failed"
    exit 1
fi
