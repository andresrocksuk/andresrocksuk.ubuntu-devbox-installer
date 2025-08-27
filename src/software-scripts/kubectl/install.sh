#!/bin/bash

# kubectl Installation Script
# This script installs the latest stable kubectl

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
    log_info "Running kubectl installation script in standalone mode"
fi

# Check if kubectl is already installed
if command -v kubectl >/dev/null 2>&1; then
    current_version=$(kubectl version --client --output=yaml 2>/dev/null | grep -o 'gitVersion: v[0-9.]*' | cut -d'v' -f2)
    log_info "kubectl is already installed (version: $current_version)"
    
    # Get latest version
    log_info "Checking for latest kubectl version..."
    latest_version=$(curl -L -s https://dl.k8s.io/release/stable.txt | cut -d'v' -f2)
    
    if [ "$current_version" = "$latest_version" ]; then
        log_success "kubectl is already up to date (version: $current_version)"
        exit 0
    else
        log_info "Newer version available: $latest_version (current: $current_version)"
        log_info "Proceeding with update..."
    fi
fi

log_info "Installing kubectl..."

# Get the latest stable version
log_info "Fetching latest kubectl version..."
latest_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)

if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest kubectl version"
    exit 1
fi

log_info "Latest kubectl version: $latest_version"

# Download kubectl binary
log_info "Downloading kubectl binary..."
curl -LO "https://dl.k8s.io/release/$latest_version/bin/linux/amd64/kubectl"

# Verify the binary
log_info "Verifying kubectl binary..."
curl -LO "https://dl.k8s.io/release/$latest_version/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

if [ $? -ne 0 ]; then
    log_error "kubectl binary verification failed"
    rm -f kubectl kubectl.sha256
    exit 1
fi

# Install kubectl
log_info "Installing kubectl to /usr/local/bin/..."
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Clean up
rm -f kubectl kubectl.sha256

# Verify installation
if command -v kubectl >/dev/null 2>&1; then
    version=$(kubectl version --client --output=yaml 2>/dev/null | grep -o 'gitVersion: v[0-9.]*' | cut -d'v' -f2)
    log_success "kubectl installed successfully (version: $version)"
    
    # Enable bash completion if bash-completion is installed
    if command -v kubectl >/dev/null 2>&1 && [ -d /etc/bash_completion.d ]; then
        log_info "Setting up kubectl bash completion..."
        kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
    fi
    
    # Show basic usage info
    log_info "To get started with kubectl:"
    log_info "  kubectl cluster-info        # Display cluster info"
    log_info "  kubectl get nodes           # List cluster nodes"
    log_info "  kubectl --help              # Show help"
    log_info ""
    log_info "Note: You'll need to configure kubectl with a kubeconfig file to connect to a cluster"
else
    log_error "kubectl installation failed"
    exit 1
fi
