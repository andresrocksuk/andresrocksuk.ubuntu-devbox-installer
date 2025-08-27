#!/bin/bash

# Zoxide Installation Script for WSL/Linux
# This script installs zoxide, a smarter cd command

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
fi

# Source environment setup utilities
if [ -f "$WSL_DIR/utils/environment-setup.sh" ]; then
    source "$WSL_DIR/utils/environment-setup.sh"
fi

# Standalone execution support
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    log_info "Running zoxide installation script in standalone mode"
fi

install_zoxide() {
    log_info "Starting zoxide installation..."
    
    # Check if zoxide is already installed
    if command -v zoxide >/dev/null 2>&1; then
        local current_version=$(zoxide --version 2>/dev/null | head -n 1)
        log_info "Zoxide is already installed: $current_version"
        return 0
    fi
    
    # Check prerequisites
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed. Please install curl first."
        return 1
    fi
    
    # Install zoxide using the official installer
    log_info "Downloading and installing zoxide..."
    
    if curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash; then
        log_info "Zoxide installation script completed"
    else
        log_error "Failed to run zoxide installation script"
        return 1
    fi
    
    # Add zoxide to PATH for current session if needed
    if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Use environment setup utility if available
    if command -v add_to_path >/dev/null 2>&1; then
        add_to_path "$HOME/.local/bin" "Zoxide binary directory"
        
        # Try to install system-wide if possible
        if [ -f "$HOME/.local/bin/zoxide" ]; then
            install_binary_system_wide "$HOME/.local/bin/zoxide" "zoxide" "/usr/local/bin"
        fi
    fi
    
    # Verify installation
    if command -v zoxide >/dev/null 2>&1; then
        local version=$(zoxide --version 2>/dev/null)
        log_info "Zoxide installed successfully: $version"
    else
        log_error "Zoxide installation failed - zoxide command not found"
        return 1
    fi
    
    # Configure shell integration
    configure_shell_integration
    
    return 0
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

# Main execution
if install_zoxide; then
    log_info "Zoxide installation completed successfully"
    log_info "Note: Restart your shell or run 'source ~/.zshrc' (or ~/.bashrc) to activate zoxide"
    log_info "Usage: Use 'z <directory>' instead of 'cd <directory>' for smart navigation"
    exit 0
else
    log_error "Zoxide installation failed"
    exit 1
fi
