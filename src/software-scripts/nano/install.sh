#!/bin/bash

# nano installation script
# Installs nano text editor via apt

set -e

# Get script directory for utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/../utils"

# Source utilities if available
if [ -f "$UTILS_DIR/logger.sh" ]; then
    source "$UTILS_DIR/logger.sh"
else
    # Fallback logging functions
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
fi

install_nano() {
    log_info "Installing nano text editor..."
    
    # Check if already installed
    if command -v nano >/dev/null 2>&1; then
        local current_version=$(nano --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' || echo "unknown")
        log_info "nano is already installed (version: $current_version)"
        return 0
    fi
    
    # Update package list
    log_info "Updating package list..."
    sudo apt-get update -qq
    
    # Install nano
    log_info "Installing nano via apt..."
    sudo apt-get install -y nano
    
    # Verify installation
    if command -v nano >/dev/null 2>&1; then
        local installed_version=$(nano --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' || echo "unknown")
        log_success "nano installed successfully (version: $installed_version)"
        
        # Test run
        log_info "Testing nano..."
        nano --help >/dev/null 2>&1 && log_success "nano test successful"
        
        return 0
    else
        log_error "nano installation verification failed"
        return 1
    fi
}

# Run installation
install_nano
