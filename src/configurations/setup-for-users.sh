#!/bin/bash

# Oh My Zsh Setup for Users Configuration Script
# This script sets up Oh My Zsh for the current user and creates setup for new users

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/utils"

# Source utilities if available (for integration with main installer)
if [ -f "$UTILS_DIR/logger.sh" ]; then
    source "$UTILS_DIR/logger.sh"
else
    # Standalone logging functions
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_debug() { echo "[DEBUG] $1"; }
fi

# Standalone execution support
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    log_info "Running Oh My Zsh setup configuration script in standalone mode"
fi

setup_oh_my_zsh() {
    log_info "Setting up Oh My Zsh..."
    
    # Get the script directory to use the existing oh-my-zsh installation script
    OH_MY_ZSH_SCRIPT="$(dirname "$SCRIPT_DIR")/custom-software/oh-my-zsh/install.sh"
    
    # Install Oh My Zsh for the current user using our existing script
    # This script will also handle setting up global scripts for new users
    if [ -f "$OH_MY_ZSH_SCRIPT" ]; then
        log_info "Installing Oh My Zsh using existing installation script..."
        bash "$OH_MY_ZSH_SCRIPT"
        
        if [ $? -eq 0 ]; then
            log_info "Oh My Zsh installed successfully!"
            log_info "Global scripts configured for consistent setup across all users."
            return 0
        else
            log_warn "Oh My Zsh installation encountered issues, but continuing..."
            return 1
        fi
    else
        log_error "Oh My Zsh installation script not found at $OH_MY_ZSH_SCRIPT"
        log_error "Skipping Oh My Zsh installation."
        return 1
    fi
}

# Main execution
if setup_oh_my_zsh; then
    log_info "Oh My Zsh setup configuration completed successfully"
    exit 0
else
    log_error "Oh My Zsh setup configuration failed"
    exit 1
fi
