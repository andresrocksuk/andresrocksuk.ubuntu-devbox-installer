#!/bin/bash

# fastfetch installation script
# Installs fastfetch from GitHub releases

set -e

# Get script directory for utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/utils"

# Configuration
SOFTWARE_NAME="fastfetch"
SOFTWARE_DESCRIPTION="fastfetch (system information display tool)"
COMMAND_NAME="fastfetch"
VERSION_FLAG="--version"
GITHUB_REPO="fastfetch-cli/fastfetch"
PACKAGE_PATTERN="linux-amd64\.deb"

# Source the installation framework if available
FRAMEWORK_AVAILABLE=false
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
    FRAMEWORK_AVAILABLE=true
fi

# Source package manager utilities
if [ -f "$UTILS_DIR/package-manager.sh" ]; then
    source "$UTILS_DIR/package-manager.sh"
fi

# Source utilities if available (fallback)
if [ -f "$UTILS_DIR/logger.sh" ]; then
    source "$UTILS_DIR/logger.sh"
else
    # Fallback logging functions
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
fi

install_fastfetch() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if already installed (using framework if available)
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_already_installed >/dev/null 2>&1; then
        if check_already_installed "$COMMAND_NAME" "$VERSION_FLAG"; then
            return 0
        fi
    else
        # Fallback: manual check
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local current_version=$(fastfetch --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_info "$SOFTWARE_DESCRIPTION is already installed (version: $current_version)"
            return 0
        fi
    fi
    
    # Use framework for GitHub release installation if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v install_from_github_release >/dev/null 2>&1; then
        if install_from_github_release "$GITHUB_REPO" "$PACKAGE_PATTERN" "$SOFTWARE_NAME" "dpkg"; then
            # Verify installation using framework
            if verify_installation "$COMMAND_NAME" "$COMMAND_NAME --help" "$SOFTWARE_NAME"; then
                local installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
                log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
                show_fastfetch_usage_info
                return 0
            else
                log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
                return 1
            fi
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "GitHub release installation failed"
            return 1
        fi
    else
        # Fallback: manual installation
        install_fastfetch_fallback
    fi
}

# Fallback installation method
install_fastfetch_fallback() {
    log_info "Using fallback installation method for $SOFTWARE_DESCRIPTION"
    
    # Get latest release info from GitHub
    local api_url="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
    
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
    if ! sudo dpkg -i "$temp_file"; then
        log_info "Fixing dependencies..."
        setup_noninteractive_apt
        safe_apt_install -f
    fi
    
    # Clean up
    rm -f "$temp_file"
    
    # Verify installation
    if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
        local installed_version=$(fastfetch --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "$SOFTWARE_DESCRIPTION installed successfully (version: $installed_version)"
        
        # Test run
        log_info "Testing fastfetch..."
        fastfetch --help >/dev/null 2>&1 && log_success "fastfetch test successful"
        
        show_fastfetch_usage_info
        return 0
    else
        log_error "$SOFTWARE_DESCRIPTION installation verification failed"
        return 1
    fi
}

# Helper function to show usage information
show_fastfetch_usage_info() {
    log_info "To use fastfetch:"
    log_info "  fastfetch                  # Display system information"
    log_info "  fastfetch --config         # Show configuration options"
    log_info "  fastfetch --help           # Show help"
    log_info ""
    log_info "fastfetch displays detailed system information in a clean format"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_fastfetch
fi
