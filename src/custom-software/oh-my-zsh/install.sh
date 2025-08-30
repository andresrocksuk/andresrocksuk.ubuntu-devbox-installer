#!/bin/bash

# oh-my-zsh installation script
# Installs oh-my-zsh framework and configures popular plugins

set -e

# Get script directory for utilities
OH_MY_ZSH_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$(dirname "$OH_MY_ZSH_SCRIPT_DIR")")/utils"

# Configuration
SOFTWARE_NAME="oh-my-zsh"
SOFTWARE_DESCRIPTION="Oh My Zsh framework"
COMMAND_NAME="zsh"
VERSION_FLAG="--version"
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"

# Source the installation framework if available
FRAMEWORK_AVAILABLE=false
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
    FRAMEWORK_AVAILABLE=true
fi

# Source utilities if available (fallback)
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
if [ -f "$OH_MY_ZSH_SCRIPT_DIR/oh-my-zsh-config.sh" ]; then
    source "$OH_MY_ZSH_SCRIPT_DIR/oh-my-zsh-config.sh"
else
    log_error "oh-my-zsh-config.sh not found in $OH_MY_ZSH_SCRIPT_DIR"
    exit 1
fi

install_oh_my_zsh() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if zsh is installed (prerequisite)
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_dependencies >/dev/null 2>&1; then
        if ! check_dependencies "zsh"; then
            log_error "zsh is required but not installed. Please install zsh first."
            return 1
        fi
    else
        # Fallback check
        if ! command -v zsh >/dev/null 2>&1; then
            log_error "zsh is not installed. Please install zsh first."
            return 1
        fi
    fi
    
    # Check if oh-my-zsh is already installed
    if [ -d "$OH_MY_ZSH_DIR" ]; then
        log_info "oh-my-zsh is already installed"
        
        # Update oh-my-zsh
        log_info "Updating oh-my-zsh..."
        if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v safely_execute >/dev/null 2>&1; then
            safely_execute "cd '$OH_MY_ZSH_DIR' && git pull" "Could not update oh-my-zsh" || log_warn "Update failed"
        else
            (cd "$OH_MY_ZSH_DIR" && git pull >/dev/null 2>&1) || log_warn "Could not update oh-my-zsh"
        fi
        
        # Still configure plugins and theme using shared configuration
        configure_oh_my_zsh
        
        if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v log_installation_result >/dev/null 2>&1; then
            log_installation_result "$SOFTWARE_NAME" "success" "already installed"
        else
            log_success "$SOFTWARE_DESCRIPTION configured successfully"
        fi
        show_oh_my_zsh_usage_info
        return 0
    fi
    
    # Try official installer first, fall back to tarball method
    if ! install_via_official_installer; then
        log_warn "Official installer failed, trying tarball method..."
        install_oh_my_zsh_tarball
    fi
    
    # Set zsh as default shell if not already
    set_default_shell
    
    # Set up global scripts for new users
    setup_global_scripts
    
    # Verify installation - check if Oh My Zsh directory exists
    if [ -d "$OH_MY_ZSH_DIR" ]; then
        log_success "$SOFTWARE_DESCRIPTION installed and configured successfully"
        show_oh_my_zsh_usage_info
        return 0
    else
        log_error "$SOFTWARE_DESCRIPTION installation verification failed"
        log_error "oh-my-zsh installation failed - verification failed"
        log_error "Oh My Zsh installation failed"
        return 1
    fi
}

# Helper function to show usage information
show_oh_my_zsh_usage_info() {
    log_info "Oh My Zsh has been installed and configured!"
    log_info "To start using it:"
    log_info "  exec zsh                   # Start a new zsh session"
    log_info "  zsh                        # Switch to zsh shell"
    log_info ""
    log_info "Features installed:"
    log_info "  - Popular plugins (git, docker, kubectl, etc.)"
    log_info "  - Powerlevel10k theme"
    log_info "  - Custom aliases and functions"
    log_info ""
    log_info "To make zsh your default shell, run: chsh -s $(which zsh)"
}

install_via_official_installer() {
    log_info "Attempting installation via official installer..."
    
    local install_script="/tmp/install_oh_my_zsh.sh"
    
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$install_script" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$install_script" https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh || return 1
    else
        log_error "Neither curl nor wget available for downloading"
        return 1
    fi
    
    # Run the installer in unattended mode
    log_info "Installing oh-my-zsh via official installer..."
    if RUNZSH=no CHSH=no sh "$install_script"; then
        # Clean up installer
        rm -f "$install_script"
        
        # Configure using shared configuration
        configure_oh_my_zsh_shared
        return 0
    else
        log_error "Official oh-my-zsh installer failed"
        rm -f "$install_script"
        return 1
    fi
}

configure_oh_my_zsh() {
    log_info "Configuring oh-my-zsh using shared configuration..."
    
    # Use the shared configuration function
    configure_oh_my_zsh_shared
    
    # Set zsh as default shell if not already
    set_default_shell
}

set_default_shell() {
    # Check current shell
    if [ "$SHELL" = "$(which zsh)" ]; then
        log_info "zsh is already the default shell"
        return 0
    fi
    
    log_info "Setting zsh as default shell..."
    
    # Check if zsh is in /etc/shells
    if ! grep -q "$(which zsh)" /etc/shells; then
        echo "$(which zsh)" | sudo tee -a /etc/shells >/dev/null
        log_info "Added zsh to /etc/shells"
    fi
    
    # Change default shell
    if chsh -s "$(which zsh)"; then
        log_success "Default shell changed to zsh"
        log_info "Please restart your terminal or run 'exec zsh' to start using zsh"
    else
        log_warn "Could not change default shell automatically"
        log_info "Run 'chsh -s \$(which zsh)' manually to set zsh as default"
    fi
}

setup_global_scripts() {
    log_info "Setting up global Oh My Zsh scripts for new users..."
    
    # Copy shared configuration to global location
    sudo mkdir -p /usr/local/share/oh-my-zsh
    if sudo cp "$OH_MY_ZSH_SCRIPT_DIR/oh-my-zsh-config.sh" /usr/local/share/oh-my-zsh/; then
        log_info "Copied shared configuration to /usr/local/share/oh-my-zsh/"
    else
        log_error "Failed to copy shared configuration"
        return 1
    fi
    
    # Create global user installation script
    sudo tee /usr/local/bin/install-oh-my-zsh-user.sh > /dev/null << 'USERSCRIPT'
#!/bin/bash
# Oh My Zsh installation script for new users

set -e

# Fallback logging functions
log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1"; }
log_success() { echo "[SUCCESS] $1"; }
log_warn() { echo "[WARN] $1"; }

# Source shared oh-my-zsh configuration
if [ -f "/usr/local/share/oh-my-zsh/oh-my-zsh-config.sh" ]; then
    source "/usr/local/share/oh-my-zsh/oh-my-zsh-config.sh"
else
    log_error "oh-my-zsh-config.sh not found in /usr/local/share/oh-my-zsh/"
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
    
    # Try to install Oh My Zsh using the tarball method
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
USERSCRIPT
    
    # Set executable permissions for all users
    if sudo chmod 755 /usr/local/bin/install-oh-my-zsh-user.sh; then
        log_success "Global Oh My Zsh user installation script created and configured"
    else
        log_error "Failed to set permissions on user installation script"
        return 1
    fi
    
    # Set readable permissions on shared configuration
    sudo chmod 644 /usr/local/share/oh-my-zsh/oh-my-zsh-config.sh
    
    log_success "Global scripts configured successfully - all users will get consistent Oh My Zsh setup"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if install_oh_my_zsh; then
        log_info "Oh My Zsh installation completed successfully"
        exit 0
    else
        log_error "Oh My Zsh installation failed"
        exit 1
    fi
fi
