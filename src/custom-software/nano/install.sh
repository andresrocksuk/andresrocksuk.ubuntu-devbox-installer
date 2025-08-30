#!/bin/bash

# Nano Text Editor Installation Script
# This script installs the nano text editor

set -e

# Determine script directory
NANO_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$(dirname "$NANO_SCRIPT_DIR")")/utils"

# Source the installation framework
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
else
    echo "[ERROR] Installation framework not found at $UTILS_DIR/installation-framework.sh"
    exit 1
fi

# Source package manager for apt functions
if [ -f "$UTILS_DIR/package-manager.sh" ]; then
    source "$UTILS_DIR/package-manager.sh"
else
    echo "[ERROR] Package manager not found at $UTILS_DIR/package-manager.sh"
    exit 1
fi

# Standalone execution support
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    log_info "Running nano installation script in standalone mode"
fi

install_nano() {
    log_info "Installing nano text editor..."
    
    # Check if already installed
    if command -v nano >/dev/null 2>&1; then
        local current_version
        current_version=$(nano --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' || echo "unknown")
        log_info "nano is already installed (version: $current_version)"
        log_success "nano is ready to use"
        show_nano_usage_info "$current_version"
        return 0
    fi
    
    # Update package list and install nano
    log_info "Updating package list..."
    update_package_lists
    
    log_info "Installing nano via apt..."
    if ! install_apt_package nano latest; then
        log_error "Failed to install nano"
        return 1
    fi
    
    # Verify installation
    if command -v nano >/dev/null 2>&1; then
        local installed_version
        installed_version=$(nano --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' || echo "unknown")
        log_success "nano installed successfully (version: $installed_version)"
        
        # Test functionality
        log_info "Testing nano functionality..."
        if nano --help >/dev/null 2>&1; then
            log_success "nano test successful"
        else
            log_warn "nano help test failed, but installation appears successful"
        fi
        
        show_nano_usage_info "$installed_version"
        return 0
    else
        log_error "nano installation verification failed"
        return 1
    fi
}

show_nano_usage_info() {
    local version="$1"
    
    log_info ""
    log_info "Nano installation completed successfully (version: $version)"
    log_info ""
    log_info "Basic nano usage:"
    log_info "  nano filename               # Edit a file"
    log_info "  nano -w filename            # Edit with no line wrapping"
    log_info "  nano +line filename         # Jump to specific line"
    log_info ""
    log_info "Common nano shortcuts:"
    log_info "  Ctrl+O                      # Save file"
    log_info "  Ctrl+X                      # Exit nano"
    log_info "  Ctrl+W                      # Search"
    log_info "  Ctrl+K                      # Cut line"
    log_info "  Ctrl+U                      # Paste"
    log_info "  Ctrl+G                      # Show help"
    log_info ""
    log_info "Documentation: https://www.nano-editor.org/docs.php"
}

# Main execution
main() {
    install_nano
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
