#!/bin/bash

# Oh My Zsh installation script for new users
# Uses the shared configuration to ensure consistency with the main installation

set -e

# Get script directory and source shared configuration
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
    log_warn() { echo "[WARN] $1"; }
fi

# Source shared oh-my-zsh configuration
if [ -f "$SCRIPT_DIR/oh-my-zsh-config.sh" ]; then
    source "$SCRIPT_DIR/oh-my-zsh-config.sh"
else
    log_error "oh-my-zsh-config.sh not found in $SCRIPT_DIR"
    log_error "Cannot continue without shared configuration"
    exit 1
fi

install_oh_my_zsh_for_user() {
    log_info "Setting up Oh My Zsh for user $(whoami)..."
    
    # Check if oh-my-zsh is already installed
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log_info "Oh My Zsh already installed for $(whoami). Applying standard configuration..."
        configure_oh_my_zsh_shared
        return 0
    fi
    
    # Check if zsh is installed
    if ! command -v zsh >/dev/null 2>&1; then
        log_error "zsh is not installed. Cannot install Oh My Zsh."
        create_fallback_zsh_config
        return 1
    fi
    
    # Try to install Oh My Zsh using the tarball method (more reliable)
    if install_oh_my_zsh_tarball; then
        log_success "Oh My Zsh installation completed successfully!"
        return 0
    else
        log_warn "Oh My Zsh installation failed. Fallback configuration applied."
        return 1
    fi
}

# Run the installation
install_oh_my_zsh_for_user
