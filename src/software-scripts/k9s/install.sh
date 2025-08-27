#!/bin/bash

# k9s installation script
# Installs k9s Kubernetes CLI from GitHub releases

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

install_k9s() {
    log_info "Installing k9s Kubernetes CLI..."
    
    # Check if already installed
    if command -v k9s >/dev/null 2>&1; then
        local current_version=$(k9s version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "k9s is already installed (version: $current_version)"
        return 0
    fi
    
    # Get latest release from GitHub
    log_info "Fetching latest k9s release..."
    local repo="derailed/k9s"
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    
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
    
    # Determine architecture
    local arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) log_error "Unsupported architecture: $arch"; return 1 ;;
    esac
    
    # Find download URL for Linux binary
    local download_url=$(echo "$release_info" | grep '"browser_download_url":' | grep "Linux_${arch}" | grep "\.tar\.gz\"" | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$tag_name" ] || [ -z "$download_url" ]; then
        log_error "Could not parse k9s release information"
        return 1
    fi
    
    log_info "Found k9s version: $tag_name"
    log_info "Download URL: $download_url"
    
    # Download and extract
    local temp_dir="/tmp/k9s-install"
    local temp_file="$temp_dir/k9s.tar.gz"
    
    mkdir -p "$temp_dir"
    
    log_info "Downloading k9s..."
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$temp_file" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$temp_file" "$download_url"
    fi
    
    # Extract the archive
    log_info "Extracting k9s..."
    cd "$temp_dir"
    tar -xzf "$temp_file"
    
    # Install the binary
    log_info "Installing k9s..."
    sudo mv k9s /usr/local/bin/k9s
    sudo chmod +x /usr/local/bin/k9s
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Verify installation
    if command -v k9s >/dev/null 2>&1; then
        local installed_version=$(k9s version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "k9s installed successfully (version: $installed_version)"
        
        # Test run
        log_info "Testing k9s..."
        k9s --help >/dev/null 2>&1 && log_success "k9s test successful"
        
        return 0
    else
        log_error "k9s installation verification failed"
        return 1
    fi
}

# Run installation
install_k9s
