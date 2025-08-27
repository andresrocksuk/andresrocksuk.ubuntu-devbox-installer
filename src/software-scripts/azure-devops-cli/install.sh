#!/bin/bash

# Azure DevOps CLI Extension Installation Script
# This script installs the Azure DevOps extension for Azure CLI

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
    log_info "Running Azure DevOps CLI installation script in standalone mode"
fi

# Check if Azure CLI is installed natively in WSL
native_az_path="/usr/bin/az"
if [ ! -f "$native_az_path" ]; then
    log_error "Native Azure CLI is required but not installed in WSL"
    log_info "Please install Azure CLI natively in WSL first"
    exit 1
fi

# Ensure we use the native Azure CLI
export PATH="/usr/bin:$PATH"
az_command="/usr/bin/az"

log_info "Azure CLI found: $($az_command version --output json 2>/dev/null | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4)"

# Check if Azure DevOps extension is already installed
if $az_command extension list --output table 2>/dev/null | grep -q "azure-devops"; then
    current_version=$($az_command extension list --output json 2>/dev/null | grep -A 5 '"name": "azure-devops"' | grep '"version"' | cut -d'"' -f4)
    log_info "Azure DevOps CLI extension is already installed (version: $current_version)"
    
    # Check for updates
    log_info "Checking for Azure DevOps CLI extension updates..."
    if $az_command extension update --name azure-devops >/dev/null 2>&1; then
        new_version=$($az_command extension list --output json 2>/dev/null | grep -A 5 '"name": "azure-devops"' | grep '"version"' | cut -d'"' -f4)
        if [ "$current_version" != "$new_version" ]; then
            log_success "Azure DevOps CLI extension upgraded from $current_version to $new_version"
        else
            log_info "Azure DevOps CLI extension is already up to date"
        fi
    else
        log_warn "Failed to check for Azure DevOps CLI extension updates"
    fi
    exit 0
fi

log_info "Installing Azure DevOps CLI extension..."

# Install the Azure DevOps extension
if $az_command extension add --name azure-devops >/dev/null 2>&1; then
    version=$($az_command extension list --output json 2>/dev/null | grep -A 5 '"name": "azure-devops"' | grep '"version"' | cut -d'"' -f4)
    log_success "Azure DevOps CLI extension installed successfully (version: $version)"
    
    # Show basic usage info
    log_info ""
    log_info "To get started with Azure DevOps CLI:"
    log_info "  az login                                    # Login to Azure"
    log_info "  az devops configure --defaults organization=<org-url>  # Set default organization"
    log_info "  az devops project list                      # List projects"
    log_info "  az repos list                               # List repositories"
    log_info "  az pipelines list                           # List pipelines"
    log_info "  az devops --help                            # Show help"
    log_info ""
    log_info "Documentation: https://docs.microsoft.com/azure/devops/cli/"
else
    log_error "Azure DevOps CLI extension installation failed"
    exit 1
fi
