#!/bin/bash

# CUE Language Installation Script
# This script installs the latest CUE (Configure, Unify, Execute) language tools

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
install_cuelang() {
    log_section "Installing CUE Language Tools"

    # Check if CUE is already installed
    if command_exists "cue"; then
        local current_version
        current_version=$(get_command_version "cue" "version")
        if [ "$current_version" != "NOT_INSTALLED" ] && [ "$current_version" != "UNKNOWN" ]; then
            log_info "CUE already installed: $current_version"
            
            # Get latest version from GitHub API
            log_info "Checking for latest CUE version..."
            local latest_version
            latest_version=$(curl -s https://api.github.com/repos/cue-lang/cue/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4)
            
            if [ "$current_version" = "$latest_version" ]; then
                log_success "CUE is already up to date: $current_version"
                return 0
            else
                log_info "Newer version available: $latest_version (current: $current_version)"
                log_info "Proceeding with update..."
            fi
        fi
    fi

    # Check prerequisites
    if ! command_exists "curl"; then
        log_error "curl is required but not installed"
        return 1
    fi

    if ! command_exists "tar"; then
        log_error "tar is required but not installed"
        return 1
    fi

    # Get the latest version from GitHub API
    log_info "Fetching latest CUE version..."
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/cue-lang/cue/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4)

    if [ -z "$latest_version" ]; then
        log_error "Failed to fetch latest CUE version"
        return 1
    fi

    log_info "Latest CUE version: $latest_version"

    # Construct download URL
    local download_url="https://github.com/cue-lang/cue/releases/download/${latest_version}/cue_${latest_version}_linux_amd64.tar.gz"

    # Create temporary directory
    local temp_dir
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
    if verify_installation "cue" "any"; then
        log_success "CUE installed successfully"
        
        # Show basic usage info
        log_info "To get started with CUE:"
        log_info "  cue help                    # Show help"
        log_info "  cue eval <file.cue>         # Evaluate a CUE file"
        log_info "  cue fmt <file.cue>          # Format a CUE file"
        log_info "  cue vet <file.cue>          # Validate a CUE file"
        log_info "  cue export <file.cue>       # Export to JSON/YAML"
        log_info "Documentation: https://cuelang.org/docs/"
        log_info "Playground: https://cuelang.org/play/"
        return 0
    else
        log_error "CUE installation failed"
        return 1
    fi
}

# Execute installation
install_cuelang "$@"
