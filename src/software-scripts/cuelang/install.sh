#!/bin/bash

# CUE Language Installation Script
# This script installs the latest CUE (Configure, Unify, Execute) language tools

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
    log_info "Running CUE language installation script in standalone mode"
fi

install_cuelang() {
    log_info "Installing CUE language tools..."

    # Check if CUE is already installed
    if command -v cue >/dev/null 2>&1; then
        current_version=$(cue version 2>/dev/null | grep -o 'v[0-9.]*' | head -1)
        log_info "CUE is already installed (version: $current_version)"
        
        # Get latest version from GitHub API
        log_info "Checking for latest CUE version..."
        latest_version=$(curl -s https://api.github.com/repos/cue-lang/cue/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4)
        
        if [ "$current_version" = "$latest_version" ]; then
            log_success "CUE is already up to date (version: $current_version)"
            return 0
        else
            log_info "Newer version available: $latest_version (current: $current_version)"
            log_info "Proceeding with update..."
        fi
    fi

    # Check prerequisites
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed"
        return 1
    fi

    if ! command -v tar >/dev/null 2>&1; then
        log_error "tar is required but not installed"
        return 1
    fi

    # Get the latest version from GitHub API
    log_info "Fetching latest CUE version..."
    latest_version=$(curl -s https://api.github.com/repos/cue-lang/cue/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4)

    if [ -z "$latest_version" ]; then
        log_error "Failed to fetch latest CUE version"
        return 1
    fi

    log_info "Latest CUE version: $latest_version"

    # Construct download URL
    download_url="https://github.com/cue-lang/cue/releases/download/${latest_version}/cue_${latest_version}_linux_amd64.tar.gz"

    # Create temporary directory
    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Download CUE
    log_info "Downloading CUE..."
    if ! curl -L "$download_url" -o "cue_${latest_version}_linux_amd64.tar.gz"; then
        log_error "Failed to download CUE"
        cd /
        rm -rf "$temp_dir"
        return 1
    fi

    # Extract CUE
    log_info "Extracting CUE..."
    if ! tar -xzf "cue_${latest_version}_linux_amd64.tar.gz"; then
        log_error "Failed to extract CUE"
        cd /
        rm -rf "$temp_dir"
        return 1
    fi

    # Install CUE
    log_info "Installing CUE to /usr/local/bin/..."
    sudo mv cue /usr/local/bin/

    # Make it executable
    sudo chmod +x /usr/local/bin/cue

    # Clean up
    cd /
    rm -rf "$temp_dir"

    # Verify installation
    if command -v cue >/dev/null 2>&1; then
        version=$(cue version 2>/dev/null | grep -o 'v[0-9.]*' | head -1)
        log_success "CUE installed successfully (version: $version)"
        
        # Show basic usage info
        log_info ""
        log_info "To get started with CUE:"
        log_info "  cue help                    # Show help"
        log_info "  cue eval <file.cue>         # Evaluate a CUE file"
        log_info "  cue fmt <file.cue>          # Format a CUE file"
        log_info "  cue vet <file.cue>          # Validate a CUE file"
        log_info "  cue export <file.cue>       # Export to JSON/YAML"
        log_info ""
        log_info "Documentation: https://cuelang.org/docs/"
        log_info "Playground: https://cuelang.org/play/"
        return 0
    else
        log_error "CUE installation failed"
        return 1
    fi
}

# Main execution
if install_cuelang; then
    log_success "CUE language installation completed successfully"
    exit 0
else
    log_error "CUE language installation failed"
    exit 1
fi
