#!/bin/bash

# Azure DevOps CLI Extension Installation Script
# This script installs the Azure DevOps extension for Azure CLI

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

# Enable error handling
set -e

# Main installation function
install_azure_devops_cli() {
    log_section "Installing Azure DevOps CLI Extension"
    
    # Check if Azure CLI is installed natively in WSL
    local native_az_path="/usr/bin/az"
    if [ ! -f "$native_az_path" ]; then
        log_error "Native Azure CLI is required but not installed in WSL"
        log_info "Please install Azure CLI natively in WSL first"
        return 1
    fi

    # Ensure we use the native Azure CLI
    export PATH="/usr/bin:$PATH"
    local az_command="/usr/bin/az"

    local azure_cli_version
    azure_cli_version=$(get_command_version "az" "version")
    log_info "Azure CLI found: $azure_cli_version"

    # Check if Azure DevOps extension is already installed
    if $az_command extension list --output table 2>/dev/null | grep -q "azure-devops"; then
        local current_version
        current_version=$($az_command extension list --output json 2>/dev/null | grep -A 5 '"name": "azure-devops"' | grep '"version"' | cut -d'"' -f4)
        log_info "Azure DevOps CLI extension already installed: $current_version"
        
        # Check for updates
        log_info "Checking for Azure DevOps CLI extension updates..."
        if $az_command extension update --name azure-devops >/dev/null 2>&1; then
            local new_version
            new_version=$($az_command extension list --output json 2>/dev/null | grep -A 5 '"name": "azure-devops"' | grep '"version"' | cut -d'"' -f4)
            if [ "$current_version" != "$new_version" ]; then
                log_success "Azure DevOps CLI extension upgraded from $current_version to $new_version"
            else
                log_info "Azure DevOps CLI extension is already up to date"
            fi
        else
            log_warn "Failed to check for Azure DevOps CLI extension updates"
        fi
        return 0
    fi

    log_info "Installing Azure DevOps CLI extension..."

    # Install the Azure DevOps extension
    if $az_command extension add --name azure-devops >/dev/null 2>&1; then
        local version
        version=$($az_command extension list --output json 2>/dev/null | grep -A 5 '"name": "azure-devops"' | grep '"version"' | cut -d'"' -f4)
        log_success "Azure DevOps CLI extension installed successfully: $version"
        
        # Show basic usage info
        log_info "To get started with Azure DevOps CLI:"
        log_info "  az login                                    # Login to Azure"
        log_info "  az devops configure --defaults organization=<org-url>  # Set default organization"
        log_info "  az devops project list                      # List projects"
        log_info "  az repos list                               # List repositories"
        log_info "  az pipelines list                           # List pipelines"
        log_info "  az devops --help                            # Show help"
        log_info "Documentation: https://docs.microsoft.com/azure/devops/cli/"
        return 0
    else
        log_error "Azure DevOps CLI extension installation failed"
        return 1
    fi
}

# Execute installation
install_azure_devops_cli "$@"
