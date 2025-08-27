#!/bin/bash

# ytt (YAML Templating Tool) Installation Script
# This script installs the latest ytt from Carvel

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
    log_info "Running ytt installation script in standalone mode"
fi

# Check if ytt is already installed
if command -v ytt >/dev/null 2>&1; then
    current_version=$(ytt version 2>/dev/null | grep -o 'ytt version [0-9.]*' | cut -d' ' -f3)
    log_info "ytt is already installed (version: $current_version)"
    
    # Get latest version from GitHub API
    log_info "Checking for latest ytt version..."
    latest_version=$(curl -s https://api.github.com/repos/carvel-dev/ytt/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4 | cut -d'v' -f2)
    
    if [ "$current_version" = "$latest_version" ]; then
        log_success "ytt is already up to date (version: $current_version)"
        exit 0
    else
        log_info "Newer version available: $latest_version (current: $current_version)"
        log_info "Proceeding with update..."
    fi
fi

log_info "Installing ytt (YAML Templating Tool)..."

# Check prerequisites
if ! command -v curl >/dev/null 2>&1; then
    log_error "curl is required but not installed"
    exit 1
fi

# Get the latest version from GitHub API
log_info "Fetching latest ytt version..."
latest_version=$(curl -s https://api.github.com/repos/carvel-dev/ytt/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4)

if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest ytt version"
    exit 1
fi

log_info "Latest ytt version: $latest_version"

# Construct download URL
download_url="https://github.com/carvel-dev/ytt/releases/download/${latest_version}/ytt-linux-amd64"

# Create temporary directory
temp_dir=$(mktemp -d)
cd "$temp_dir"

log_info "Downloading ytt..."
if ! curl -sL "$download_url" -o ytt; then
    log_error "Failed to download ytt"
    cd /
    rm -rf "$temp_dir"
    exit 1
fi

# Install ytt
log_info "Installing ytt to /usr/local/bin/..."
sudo mv ytt /usr/local/bin/

# Make it executable
sudo chmod +x /usr/local/bin/ytt

# Clean up
cd /
rm -rf "$temp_dir"

# Verify installation
if command -v ytt >/dev/null 2>&1; then
    version=$(ytt version 2>/dev/null | grep -o 'ytt version [0-9.]*' | cut -d' ' -f3)
    log_success "ytt installed successfully (version: $version)"
    
    # Show basic usage info
    log_info ""
    log_info "To get started with ytt:"
    log_info "  ytt -f template.yml                # Process a YAML template"
    log_info "  ytt -f template.yml --data-values-file values.yml  # With data values"
    log_info "  ytt --help                          # Show help"
    log_info ""
    log_info "Documentation: https://carvel.dev/ytt/"
    log_info "Examples: https://carvel.dev/ytt/docs/latest/lang/"
else
    log_error "ytt installation failed"
    exit 1
fi
