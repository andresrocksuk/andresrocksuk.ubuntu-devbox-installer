#!/bin/bash

# Azure CLI Installation Script
# This script installs the latest Azure CLI

# Get script directory for reliable path resolution
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../../utils"

# Source installation framework
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
else
    echo "Error: installation-framework.sh not found at $UTILS_DIR/installation-framework.sh"
    exit 1
fi

# Source package manager utilities
if [ -f "$UTILS_DIR/package-manager.sh" ]; then
    source "$UTILS_DIR/package-manager.sh"
fi

# Enable error handling
set -e

# Main installation function
install_azure_cli() {
    log_section "Installing Azure CLI"
    
    # Check if Azure CLI is already installed natively in WSL
    # We want to ensure we have the Linux version, not Windows version accessed through PATH
    local native_az_path="/usr/bin/az"
    if [ -f "$native_az_path" ] && command_exists "az"; then
        local current_version
        current_version=$(get_command_version "az" "version")
        if [ "$current_version" != "NOT_INSTALLED" ] && [ "$current_version" != "UNKNOWN" ]; then
            log_info "Azure CLI already installed: $current_version"
            
            # Check for updates
            log_info "Checking for Azure CLI updates..."
            export DEBIAN_FRONTEND=noninteractive
            if timeout 300 az upgrade --all --yes; then
                local new_version
                new_version=$(get_command_version "az" "version")
                if [ "$current_version" != "$new_version" ]; then
                    log_success "Azure CLI upgraded from $current_version to $new_version"
                else
                    log_info "Azure CLI is already up to date"
                fi
            else
                log_warn "Failed to check for Azure CLI updates (may have timed out)"
            fi
            return 0
        fi
    fi

    # If we reach here, either Azure CLI is not installed natively or there's an issue
    # Remove any Windows PATH interference for this installation
    log_info "Ensuring clean installation environment..."

    log_info "Installing Azure CLI..."

    # Check if running on supported OS
    if ! grep -q "Ubuntu\|Debian" /etc/os-release; then
        log_error "This script is designed for Ubuntu/Debian systems"
        return 1
    fi

    # Install prerequisites
    log_info "Installing prerequisites..."
    install_apt_package "ca-certificates" "latest"
    install_apt_package "curl" "latest"
    install_apt_package "apt-transport-https" "latest"
    install_apt_package "lsb-release" "latest"
    install_apt_package "gnupg" "latest"

    # Download and install Microsoft signing key
    log_info "Adding Microsoft repository signing key..."
    sudo mkdir -p /etc/apt/keyrings
    
    if timeout 120 curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null; then
        log_info "Microsoft signing key added successfully"
        sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
    else
        log_error "Failed to download and install Microsoft signing key"
        return 1
    fi

    # Add Azure CLI repository
    log_info "Adding Azure CLI repository..."
    local az_repo
    az_repo=$(lsb_release -cs)
    if echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $az_repo main" | sudo tee /etc/apt/sources.list.d/azure-cli.list >/dev/null; then
        log_info "Azure CLI repository added successfully"
    else
        log_error "Failed to add Azure CLI repository"
        return 1
    fi

    # Update package list and install Azure CLI
    log_info "Installing Azure CLI package..."
    setup_noninteractive_apt
    
    if safe_apt_update; then
        log_info "Package list updated successfully"
    else
        log_error "Failed to update package list for Azure CLI"
        return 1
    fi
    
    if safe_apt_install azure-cli; then
        log_info "Azure CLI package installed successfully"
    else
        log_error "Failed to install Azure CLI package"
        return 1
    fi

    # Verify installation
    if verify_installation "az" "any"; then
        log_success "Azure CLI installed successfully"
        
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
        return 0
    else
        log_error "Azure CLI installation failed"
        return 1
    fi
}

# Execute installation
install_azure_cli "$@"
