#!/bin/bash

# Helm Installation Script
# This script installs the latest Helm (Kubernetes package manager)

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
    log_info "Running Helm installation script in standalone mode"
fi

# Check if Helm is already installed
if command -v helm >/dev/null 2>&1; then
    current_version=$(helm version --short --client 2>/dev/null | grep -o 'v[0-9.]*' | head -1)
    log_info "Helm is already installed (version: $current_version)"
    
    # Get latest version from GitHub API
    log_info "Checking for latest Helm version..."
    latest_version=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4)
    
    if [ "$current_version" = "$latest_version" ]; then
        log_success "Helm is already up to date (version: $current_version)"
        exit 0
    else
        log_info "Newer version available: $latest_version (current: $current_version)"
        log_info "Proceeding with update..."
    fi
fi

log_info "Installing Helm..."

# Check prerequisites
if ! command -v curl >/dev/null 2>&1; then
    log_error "curl is required but not installed"
    exit 1
fi

# Get the latest version from GitHub API
log_info "Fetching latest Helm version..."
latest_version=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4)

if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest Helm version"
    exit 1
fi

log_info "Latest Helm version: $latest_version"

# Download Helm using the official install script
log_info "Downloading and running Helm install script..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

# Verify the script downloaded successfully
if [ ! -f get_helm.sh ]; then
    log_error "Failed to download Helm install script"
    exit 1
fi

# Make the script executable and run it
chmod 700 get_helm.sh

# Run the install script
if ./get_helm.sh; then
    log_info "Helm install script completed"
else
    log_error "Helm install script failed"
    rm -f get_helm.sh
    exit 1
fi

# Clean up
rm -f get_helm.sh

# Verify installation
if command -v helm >/dev/null 2>&1; then
    version=$(helm version --short --client 2>/dev/null | grep -o 'v[0-9.]*' | head -1)
    log_success "Helm installed successfully (version: $version)"
    
    # Enable bash completion if bash-completion is installed
    if command -v helm >/dev/null 2>&1 && [ -d /etc/bash_completion.d ]; then
        log_info "Setting up Helm bash completion..."
        helm completion bash | sudo tee /etc/bash_completion.d/helm > /dev/null
    fi
    
    # Show basic usage info
    log_info "To get started with Helm:"
    log_info "  helm repo add stable https://charts.helm.sh/stable    # Add stable repo"
    log_info "  helm repo update                                     # Update repos"
    log_info "  helm search repo <chart-name>                       # Search for charts"
    log_info "  helm install <release-name> <chart>                 # Install a chart"
    log_info "  helm --help                                          # Show help"
    log_info ""
    log_info "Note: Helm requires kubectl to be configured with access to a Kubernetes cluster"
else
    log_error "Helm installation failed"
    exit 1
fi
