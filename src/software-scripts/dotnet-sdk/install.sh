#!/bin/bash

# .NET SDK Installation Script
# This script installs the latest .NET SDK 8

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
    log_info "Running .NET SDK installation script in standalone mode"
fi

# Check if .NET SDK is already installed
if command -v dotnet >/dev/null 2>&1; then
    current_version=$(dotnet --version 2>/dev/null)
    log_info ".NET SDK is already installed (version: $current_version)"
    
    # Check if it's .NET 8.x
    if [[ "$current_version" == 8.* ]]; then
        log_success ".NET SDK 8.x is already installed and up to date"
        exit 0
    else
        log_info "Current version is $current_version, installing .NET 8.x..."
    fi
fi

log_info "Installing .NET SDK 8..."

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

# Download Microsoft package signing key
log_info "Adding Microsoft package signing key..."
wget https://packages.microsoft.com/config/ubuntu/$ubuntu_version/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# Update package list
log_info "Updating package lists..."
sudo apt-get update >/dev/null 2>&1

# Install .NET SDK 8
log_info "Installing .NET SDK 8..."
sudo apt-get install -y dotnet-sdk-8.0 >/dev/null 2>&1

# Verify installation
if command -v dotnet >/dev/null 2>&1; then
    version=$(dotnet --version 2>/dev/null)
    log_success ".NET SDK installed successfully (version: $version)"
    
    # Show installed SDKs and runtimes
    log_info "Installed .NET SDKs:"
    dotnet --list-sdks 2>/dev/null | sed 's/^/  /'
    
    log_info "Installed .NET Runtimes:"
    dotnet --list-runtimes 2>/dev/null | sed 's/^/  /'
    
    # Show basic usage info
    log_info ""
    log_info "To get started with .NET:"
    log_info "  dotnet new console -n MyApp    # Create a new console application"
    log_info "  dotnet run                      # Run the application"
    log_info "  dotnet build                    # Build the application"
    log_info "  dotnet --help                   # Show help"
    log_info ""
    log_info "Documentation: https://docs.microsoft.com/dotnet/"
else
    log_error ".NET SDK installation failed"
    exit 1
fi
