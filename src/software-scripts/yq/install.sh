#!/bin/bash

# yq installation script
# Installs yq (YAML processor) from GitHub releases

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

install_yq() {
    log_info "Installing yq (YAML processor)..."
    
    # Check if already installed
    if command -v yq >/dev/null 2>&1; then
        local current_version=$(yq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")
        log_info "yq is already installed (version: $current_version)"
        return 0
    fi
    
    # Get system architecture
    local arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv6l) arch="arm" ;;
        armv7l) arch="arm" ;;
        *) 
            log_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    
    # Get latest release info from GitHub
    local repo="mikefarah/yq"
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
    local download_url=$(echo "$release_info" | grep '"browser_download_url":.*yq_linux_'$arch'"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$tag_name" ] || [ -z "$download_url" ]; then
        log_error "Could not parse release information"
        return 1
    fi
    
    log_info "Found yq version: $tag_name"
    log_info "Download URL: $download_url"
    
    # Download yq binary
    local temp_file="/tmp/yq"
    
    log_info "Downloading yq..."
    if command -v curl >/dev/null 2>&1; then
        curl -sL -o "$temp_file" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$temp_file" "$download_url"
    fi
    
    # Make executable and move to /usr/local/bin
    chmod +x "$temp_file"
    sudo mv "$temp_file" /usr/local/bin/yq
    
    # Verify installation
    if command -v yq >/dev/null 2>&1; then
        local installed_version=$(yq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")
        log_success "yq installed successfully (version: $installed_version)"
        
        # Test yq installation
        log_info "Testing yq installation..."
        echo "test: value" | yq eval '.test' - >/dev/null && log_success "yq test successful"
        
        return 0
    else
        log_error "yq installation verification failed"
        return 1
    fi
}

# Run installation
install_yq
