#!/bin/bash

# fastfetch installation script
# Installs fastfetch from GitHub releases

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

install_fastfetch() {
    log_info "Installing fastfetch..."
    
    # Check if already installed
    if command -v fastfetch >/dev/null 2>&1; then
        local current_version=$(fastfetch --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "fastfetch is already installed (version: $current_version)"
        return 0
    fi
    
    # Get latest release info from GitHub
    local repo="fastfetch-cli/fastfetch"
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    
    log_info "Fetching latest release information..."
    
    local release_info
    if command -v curl >/dev/null 2>&1; then
        release_info=$(curl -s "$api_url")
    elif command -v wget >/dev/null 2>&1; then
        release_info=$(wget -qO- "$api_url")
    else
        log_error "Neither curl nor wget available for downloading"
        return 1
    fi
    
    # Parse release information
    local tag_name=$(echo "$release_info" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    local download_url=$(echo "$release_info" | grep '"browser_download_url":.*linux-amd64\.deb"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$tag_name" ] || [ -z "$download_url" ]; then
        log_error "Could not parse release information"
        return 1
    fi
    
    log_info "Found fastfetch version: $tag_name"
    log_info "Download URL: $download_url"
    
    # Download the .deb package
    local temp_file="/tmp/fastfetch.deb"
    
    log_info "Downloading fastfetch..."
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$temp_file" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$temp_file" "$download_url"
    fi
    
    # Install the package
    log_info "Installing fastfetch package..."
    sudo dpkg -i "$temp_file" || {
        log_info "Fixing dependencies..."
        sudo apt-get install -f -y
    }
    
    # Clean up
    rm -f "$temp_file"
    
    # Verify installation
    if command -v fastfetch >/dev/null 2>&1; then
        local installed_version=$(fastfetch --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "fastfetch installed successfully (version: $installed_version)"
        
        # Test run
        log_info "Testing fastfetch..."
        fastfetch --help >/dev/null 2>&1 && log_success "fastfetch test successful"
        
        return 0
    else
        log_error "fastfetch installation verification failed"
        return 1
    fi
}

# Run installation
install_fastfetch
