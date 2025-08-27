#!/bin/bash

# oh-my-zsh installation script
# Installs oh-my-zsh framework and configures popular plugins

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
    log_warn() { echo "[WARN] $1"; }
fi

# Source shared oh-my-zsh configuration
if [ -f "$SCRIPT_DIR/oh-my-zsh-config.sh" ]; then
    source "$SCRIPT_DIR/oh-my-zsh-config.sh"
else
    log_error "oh-my-zsh-config.sh not found in $SCRIPT_DIR"
    exit 1
fi

install_oh_my_zsh() {
    log_info "Installing oh-my-zsh..."
    
    # Check if zsh is installed
    if ! command -v zsh >/dev/null 2>&1; then
        log_error "zsh is not installed. Please install zsh first."
        return 1
    fi
    
    # Check if oh-my-zsh is already installed
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log_info "oh-my-zsh is already installed"
        
        # Update oh-my-zsh
        log_info "Updating oh-my-zsh..."
        cd "$HOME/.oh-my-zsh" && git pull >/dev/null 2>&1 || log_warn "Could not update oh-my-zsh"
        
        # Still configure plugins and theme using shared configuration
        configure_oh_my_zsh
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
    
    log_success "oh-my-zsh installed and configured successfully"
    return 0
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
    if sudo cp "$SCRIPT_DIR/oh-my-zsh-config.sh" /usr/local/share/oh-my-zsh/; then
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

# Run installation
install_oh_my_zsh
