#!/bin/bash

# Zoxide installation script
# Installs zoxide, a smarter cd command

set -e

# Get script directory for utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/utils"

# Configuration
SOFTWARE_NAME="zoxide"
SOFTWARE_DESCRIPTION="Zoxide (smarter cd command)"
COMMAND_NAME="zoxide"
VERSION_FLAG="--version"
INSTALLER_URL="https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh"
INSTALL_DIR="$HOME/.local/bin"

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
    log_debug() { echo "[DEBUG] $1"; }
fi

# Source environment setup utilities
if [ -f "$UTILS_DIR/environment-setup.sh" ]; then
    source "$UTILS_DIR/environment-setup.sh"
fi

install_zoxide() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if already installed (using framework if available)
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_already_installed >/dev/null 2>&1; then
        if check_already_installed "$COMMAND_NAME" "$VERSION_FLAG"; then
            return 0
        fi
    else
        # Fallback: manual check
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local current_version=$(zoxide --version 2>/dev/null | head -n 1)
            log_info "$SOFTWARE_DESCRIPTION is already installed: $current_version"
            return 0
        fi
    fi
    
    # Check prerequisites
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_dependencies >/dev/null 2>&1; then
        if ! check_dependencies "curl"; then
            return 1
        fi
    else
        # Fallback: manual check
        if ! command -v curl >/dev/null 2>&1; then
            log_error "curl is required but not installed. Please install curl first."
            return 1
        fi
    fi
    
    # Download and run installer
    log_info "Downloading and installing zoxide using official installer..."
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v safely_execute >/dev/null 2>&1; then
        if ! safely_execute "curl -sS '$INSTALLER_URL' | bash" "Failed to download and run zoxide installer"; then
            return 1
        fi
    else
        # Fallback execution
        if ! curl -sS "$INSTALLER_URL" | bash; then
            log_error "Failed to run zoxide installation script"
            return 1
        fi
    fi
    
    # Setup environment
    setup_zoxide_environment
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "$COMMAND_NAME --version" "zoxide"; then
            local installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null)
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            show_zoxide_usage_info
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local version=$(zoxide --version 2>/dev/null)
            log_success "$SOFTWARE_DESCRIPTION installed successfully: $version"
            show_zoxide_usage_info
            return 0
        else
            log_error "$SOFTWARE_DESCRIPTION installation failed - zoxide command not found"
            return 1
        fi
    fi
}

# Helper function to setup zoxide environment
setup_zoxide_environment() {
    # Add zoxide to PATH for current session if needed
    if [ -d "$INSTALL_DIR" ] && [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        export PATH="$INSTALL_DIR:$PATH"
    fi
    
    # Use environment setup utility if available
    if command -v add_to_path >/dev/null 2>&1; then
        add_to_path "$INSTALL_DIR" "Zoxide binary directory"
        
        # Try to install system-wide if possible
        if [ -f "$INSTALL_DIR/zoxide" ]; then
            install_binary_system_wide "$INSTALL_DIR/zoxide" "zoxide" "/usr/local/bin"
        fi
    fi
    
    # Configure shell integration
    configure_shell_integration
}

# Helper function to show usage information
show_zoxide_usage_info() {
    log_info "To use zoxide:"
    log_info "  z <directory>              # Smart directory navigation"
    log_info "  zi                         # Interactive directory picker"
    log_info "  z --help                   # Show help"
    log_info ""
    log_info "Note: Restart your shell or run 'source ~/.zshrc' (or ~/.bashrc) to activate zoxide"
    log_info "Usage: Use 'z <directory>' instead of 'cd <directory>' for smart navigation"
}

configure_shell_integration() {
    log_info "Configuring zoxide shell integration..."
    
    # Use environment setup utility if available
    if command -v source_script_in_profiles >/dev/null 2>&1; then
        # For shell integration, we need to add the init command
        local zoxide_init_zsh='eval "$(zoxide init zsh)"'
        local zoxide_init_bash='eval "$(zoxide init bash)"'
        
        # Update user profiles
        if [ -f "$HOME/.zshrc" ]; then
            if ! grep -q "zoxide init" "$HOME/.zshrc" 2>/dev/null; then
                echo "" >> "$HOME/.zshrc"
                echo "# Zoxide integration" >> "$HOME/.zshrc"
                echo "$zoxide_init_zsh" >> "$HOME/.zshrc"
                log_info "Added zoxide integration to ~/.zshrc"
            fi
        fi
        
        if [ -f "$HOME/.bashrc" ]; then
            if ! grep -q "zoxide init" "$HOME/.bashrc" 2>/dev/null; then
                echo "" >> "$HOME/.bashrc"
                echo "# Zoxide integration" >> "$HOME/.bashrc"
                echo "$zoxide_init_bash" >> "$HOME/.bashrc"
                log_info "Added zoxide integration to ~/.bashrc"
            fi
        fi
        
        # Update skeleton files for new users
        update_skeleton_files "$zoxide_init_bash" "Zoxide shell integration"
        
    else
        # Fallback to original method
        configure_shell_integration_fallback
    fi
}

configure_shell_integration_fallback() {
    log_info "Using fallback shell integration setup for zoxide"
    
    # Configure zsh integration
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "zoxide init" "$HOME/.zshrc" 2>/dev/null; then
            log_info "Adding zoxide integration to ~/.zshrc"
            echo "" >> "$HOME/.zshrc"
            echo "# Zoxide integration" >> "$HOME/.zshrc"
            echo 'eval "$(zoxide init zsh)"' >> "$HOME/.zshrc"
        else
            log_info "Zoxide integration already configured in ~/.zshrc"
        fi
    fi
    
    # Configure bash integration
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "zoxide init" "$HOME/.bashrc" 2>/dev/null; then
            log_info "Adding zoxide integration to ~/.bashrc"
            echo "" >> "$HOME/.bashrc"
            echo "# Zoxide integration" >> "$HOME/.bashrc"
            echo 'eval "$(zoxide init bash)"' >> "$HOME/.bashrc"
        else
            log_info "Zoxide integration already configured in ~/.bashrc"
        fi
    fi
    
    # Update skeleton files using environment setup utilities if available
    if command -v update_skeleton_files >/dev/null 2>&1; then
        # Use the standard environment setup approach for bash
        update_skeleton_files 'eval "$(zoxide init bash)"' "Zoxide integration"
        
        # Create separate zoxide configuration for zsh integration
        create_zoxide_zsh_integration
    else
        # Use fallback method
        update_skeleton_files_fallback
    fi
}

# Create separate zoxide configuration for zsh integration
create_zoxide_zsh_integration() {
    log_info "Creating zoxide zsh integration configuration"
    
    # Create a configuration snippet that can be sourced by zsh configurations
    local zoxide_config_dir="/usr/local/share/zoxide"
    local zoxide_config_file="$zoxide_config_dir/zoxide.zsh"
    
    if sudo -n true 2>/dev/null; then
        sudo mkdir -p "$zoxide_config_dir"
        sudo tee "$zoxide_config_file" > /dev/null << 'EOF'
# Zoxide smart directory navigation
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi
EOF
        sudo chmod 644 "$zoxide_config_file"
        log_info "Created zoxide configuration at $zoxide_config_file"
        log_info "This will be automatically loaded by the zsh configuration system"
    else
        log_warn "Cannot create system-wide zoxide configuration (no sudo access)"
    fi
}

update_skeleton_files_fallback() {
    log_info "Updating skeleton files for new users (fallback method)..."
    
    # Create separate zoxide configuration for zsh (never touch /etc/skel/.zshrc)
    create_zoxide_zsh_integration
    
    # Only update bash skeleton to avoid conflicts with zsh setup
    if [ -f /etc/skel/.bashrc ]; then
        if ! sudo grep -q "zoxide init" /etc/skel/.bashrc 2>/dev/null; then
            echo "" | sudo tee -a /etc/skel/.bashrc > /dev/null
            echo "# Zoxide integration" | sudo tee -a /etc/skel/.bashrc > /dev/null
            echo 'eval "$(zoxide init bash)"' | sudo tee -a /etc/skel/.bashrc > /dev/null
            log_info "Added zoxide integration to /etc/skel/.bashrc"
        fi
    fi
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if install_zoxide; then
        log_info "Zoxide installation completed successfully"
        exit 0
    else
        log_error "Zoxide installation failed"
        exit 1
    fi
fi
