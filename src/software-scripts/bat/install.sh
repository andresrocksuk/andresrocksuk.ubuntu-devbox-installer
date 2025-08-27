#!/bin/bash

# bat installation script
# Installs bat (better cat) via apt

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

install_bat() {
    log_info "Installing bat (better cat with syntax highlighting)..."
    
    # Check if already installed
    if command -v bat >/dev/null 2>&1; then
        local current_version=$(bat --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "bat is already installed (version: $current_version)"
        return 0
    fi
    
    # Check if batcat is installed (Ubuntu package name)
    if command -v batcat >/dev/null 2>&1; then
        local current_version=$(batcat --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "bat is already installed as batcat (version: $current_version)"
        
        # Create alias if bat command doesn't exist
        if ! command -v bat >/dev/null 2>&1; then
            log_info "Creating bat alias for batcat..."
            sudo ln -sf $(which batcat) /usr/local/bin/bat
        fi
        return 0
    fi
    
    # Update package list
    log_info "Updating package list..."
    sudo apt-get update -qq
    
    # Install bat
    log_info "Installing bat via apt..."
    sudo apt-get install -y bat
    
    # Create bat alias if only batcat is available
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
        log_info "Creating bat alias for batcat..."
        sudo ln -sf $(which batcat) /usr/local/bin/bat
    fi
    
    # Verify installation
    local bat_cmd="bat"
    if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
        bat_cmd="batcat"
    fi
    
    if command -v $bat_cmd >/dev/null 2>&1; then
        local installed_version=$($bat_cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "bat installed successfully (version: $installed_version)"
        
        # Test run
        log_info "Testing bat..."
        $bat_cmd --help >/dev/null 2>&1 && log_success "bat test successful"
        
        return 0
    else
        log_error "bat installation verification failed"
        return 1
    fi
}

# Run installation
install_bat
