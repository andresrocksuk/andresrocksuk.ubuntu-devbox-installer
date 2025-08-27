#!/bin/bash

# Azure CLI Installation Script
# This script installs the latest Azure CLI

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
    log_info "Running Azure CLI installation script in standalone mode"
fi

# Check if Azure CLI is already installed natively in WSL
# We want to ensure we have the Linux version, not Windows version accessed through PATH
native_az_path="/usr/bin/az"
if [ -f "$native_az_path" ] && command -v az >/dev/null 2>&1; then
    current_version=$(az version --output json 2>/dev/null | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4)
    if [ -n "$current_version" ]; then
        log_info "Azure CLI is already installed natively (version: $current_version)"
        
        # Check for updates
        log_info "Checking for Azure CLI updates..."
        if az upgrade --all --yes >/dev/null 2>&1; then
            new_version=$(az version --output json 2>/dev/null | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4)
            if [ "$current_version" != "$new_version" ]; then
                log_success "Azure CLI upgraded from $current_version to $new_version"
            else
                log_info "Azure CLI is already up to date"
            fi
        else
            log_warn "Failed to check for Azure CLI updates"
        fi
        exit 0
    fi
fi

# If we reach here, either Azure CLI is not installed natively or there's an issue
# Remove any Windows PATH interference for this installation
log_info "Ensuring clean installation environment..."

log_info "Installing Azure CLI..."

# Check if running on supported OS
if ! grep -q "Ubuntu\|Debian" /etc/os-release; then
    log_error "This script is designed for Ubuntu/Debian systems"
    exit 1
fi

# Install prerequisites
log_info "Installing prerequisites..."
sudo apt-get update >/dev/null 2>&1
sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg >/dev/null 2>&1

# Download and install Microsoft signing key
log_info "Adding Microsoft repository signing key..."
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

# Add Azure CLI repository
log_info "Adding Azure CLI repository..."
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list > /dev/null

# Update package list and install Azure CLI
log_info "Installing Azure CLI package..."
sudo apt-get update >/dev/null 2>&1
sudo apt-get install -y azure-cli >/dev/null 2>&1

# Verify installation - make sure we're using the native version
if [ -f "/usr/bin/az" ] && /usr/bin/az version >/dev/null 2>&1; then
    version=$(/usr/bin/az version --output json 2>/dev/null | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4)
    log_success "Azure CLI installed successfully (version: $version)"
    
    # Ensure native Azure CLI takes precedence in PATH
    if ! grep -q "/usr/bin" <<< "$PATH" | head -1; then
        log_info "Adding /usr/bin to front of PATH for this session..."
        export PATH="/usr/bin:$PATH"
    fi
    
    # Show basic usage info
    log_info "To get started with Azure CLI:"
    log_info "  az login                    # Login to Azure"
    log_info "  az account list             # List available subscriptions"
    log_info "  az --help                   # Show help"
else
    log_error "Azure CLI installation failed"
    exit 1
fi
