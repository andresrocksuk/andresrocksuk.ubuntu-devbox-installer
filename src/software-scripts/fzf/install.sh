#!/bin/bash

# fzf installation script
# Installs fzf (fuzzy finder) from GitHub

set -e

# Get script directory for utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/utils"

# Configuration
SOFTWARE_NAME="fzf"
SOFTWARE_DESCRIPTION="fzf (fuzzy finder)"
COMMAND_NAME="fzf"
VERSION_FLAG="--version"
GITHUB_REPO="junegunn/fzf"
INSTALL_DIR="$HOME/.fzf"

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

# Source environment setup utilities
if [ -f "$UTILS_DIR/environment-setup.sh" ]; then
    source "$UTILS_DIR/environment-setup.sh"
fi

install_fzf() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if already installed (using framework if available)
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_already_installed >/dev/null 2>&1; then
        if check_already_installed "$COMMAND_NAME" "$VERSION_FLAG"; then
            return 0
        fi
    else
        # Fallback: manual check
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local current_version=$(fzf --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_info "$SOFTWARE_DESCRIPTION is already installed (version: $current_version)"
            return 0
        fi
    fi
    
    # Clone or update fzf repository
    if [ -d "$INSTALL_DIR" ]; then
        log_info "fzf directory already exists, updating..."
        cd "$INSTALL_DIR"
        if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v safely_execute >/dev/null 2>&1; then
            if ! safely_execute "git pull" "Failed to update fzf repository"; then
                log_error "Failed to update existing fzf installation"
                return 1
            fi
        else
            git pull || {
                log_error "Failed to update fzf repository"
                return 1
            }
        fi
    else
        log_info "Cloning fzf repository..."
        if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v safely_execute >/dev/null 2>&1; then
            if ! safely_execute "git clone --depth 1 https://github.com/$GITHUB_REPO.git \"$INSTALL_DIR\"" "Failed to clone fzf repository"; then
                return 1
            fi
        else
            git clone --depth 1 "https://github.com/$GITHUB_REPO.git" "$INSTALL_DIR" || {
                log_error "Failed to clone fzf repository"
                return 1
            }
        fi
        cd "$INSTALL_DIR"
    fi
    
    # Install fzf
    log_info "Installing fzf..."
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v safely_execute >/dev/null 2>&1; then
        if ! safely_execute "./install --all --no-update-rc" "Failed to install fzf"; then
            return 1
        fi
    else
        ./install --all --no-update-rc || {
            log_error "Failed to install fzf"
            return 1
        }
    fi
    
    # Setup PATH and environment
    setup_fzf_environment
    
    # Verify installation using framework if available
    local fzf_cmd="$COMMAND_NAME"
    if ! command -v "$COMMAND_NAME" >/dev/null 2>&1 && [ -f "$INSTALL_DIR/bin/fzf" ]; then
        fzf_cmd="$INSTALL_DIR/bin/fzf"
        export PATH="$INSTALL_DIR/bin:$PATH"
    fi
    
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$fzf_cmd" "echo 'test' | $fzf_cmd --filter='test'" "fzf"; then
            local installed_version=$(get_command_version "$fzf_cmd" "$VERSION_FLAG" 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            show_fzf_usage_info
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$fzf_cmd" >/dev/null 2>&1 || [ -f "$INSTALL_DIR/bin/fzf" ]; then
            local installed_version=$($fzf_cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_success "$SOFTWARE_DESCRIPTION installed successfully (version: $installed_version)"
            
            # Test run
            log_info "Testing fzf..."
            echo "test" | $fzf_cmd --filter="test" >/dev/null 2>&1 && log_success "fzf test successful"
            
            show_fzf_usage_info
            return 0
        else
            log_error "$SOFTWARE_DESCRIPTION installation verification failed"
            return 1
        fi
    fi
}

# Helper function to setup fzf environment
setup_fzf_environment() {
    # Add to PATH if not already there
    if ! command -v fzf >/dev/null 2>&1; then
        log_info "Setting up fzf environment..."
        
        # Use environment setup utility if available
        if command -v add_to_path >/dev/null 2>&1; then
            add_to_path "$INSTALL_DIR/bin" "fzf binary directory"
            
            # Try to install system-wide if possible
            if [ -f "$INSTALL_DIR/bin/fzf" ]; then
                install_binary_system_wide "$INSTALL_DIR/bin/fzf" "fzf" "/usr/local/bin"
            fi
            
            # Update skeleton files for new users
            update_skeleton_files "export PATH=\"\$HOME/.fzf/bin:\$PATH\"" "fzf fuzzy finder PATH"
            
        else
            # Fallback to original method
            setup_fzf_environment_fallback
        fi
        
        # Export for current session
        export PATH="$INSTALL_DIR/bin:$PATH"
    fi
}

# Helper function to show usage information
show_fzf_usage_info() {
    log_info "To use fzf:"
    log_info "  fzf                        # Interactive fuzzy finder"
    log_info "  command | fzf              # Filter command output"
    log_info "  Ctrl+R                     # Search command history (if shell integration enabled)"
    log_info "  Ctrl+T                     # Search files (if shell integration enabled)"
    log_info "  Alt+C                      # Change directory (if shell integration enabled)"
    log_info ""
    log_info "fzf provides powerful fuzzy finding capabilities for the command line"
}

# Fallback function for setting up fzf environment
setup_fzf_environment_fallback() {
    log_info "Using fallback environment setup for fzf"
    
    # Add to bashrc
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "\.fzf/bin" "$HOME/.bashrc" 2>/dev/null; then
            echo "" >> "$HOME/.bashrc"
            echo "# fzf fuzzy finder PATH" >> "$HOME/.bashrc"
            echo 'export PATH="$HOME/.fzf/bin:$PATH"' >> "$HOME/.bashrc"
            log_info "Added fzf to ~/.bashrc"
        fi
    fi
    
    # Add to zshrc if it exists
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "\.fzf/bin" "$HOME/.zshrc" 2>/dev/null; then
            echo "" >> "$HOME/.zshrc"
            echo "# fzf fuzzy finder PATH" >> "$HOME/.zshrc"
            echo 'export PATH="$HOME/.fzf/bin:$PATH"' >> "$HOME/.zshrc"
            log_info "Added fzf to ~/.zshrc"
        fi
    fi
    
    # Update skeleton files using environment-setup utilities if available
    if command -v update_skeleton_files >/dev/null 2>&1; then
        update_skeleton_files 'export PATH="$HOME/.fzf/bin:$PATH"' "fzf fuzzy finder PATH"
    else
        # Try to update skeleton files manually (only for .bashrc to avoid zsh conflicts)
        if sudo -n true 2>/dev/null; then
            log_info "Updating skeleton files for new users (fallback method)"
            
            # Only update .bashrc skeleton to avoid conflicts with zsh setup
            local skel_file="/etc/skel/.bashrc"
            if [ -f "$skel_file" ]; then
                if ! sudo grep -q "\.fzf/bin" "$skel_file" 2>/dev/null; then
                    echo "" | sudo tee -a "$skel_file" > /dev/null
                    echo "# fzf fuzzy finder PATH" | sudo tee -a "$skel_file" > /dev/null
                    echo 'export PATH="$HOME/.fzf/bin:$PATH"' | sudo tee -a "$skel_file" > /dev/null
                    log_info "Updated $skel_file"
                fi
            fi
            
            # For zsh skeleton, create a separate configuration file
            create_fzf_zsh_integration
        fi
    fi
}

# Create separate fzf configuration for zsh integration
create_fzf_zsh_integration() {
    log_info "Creating fzf zsh integration configuration"
    
    # Create a configuration snippet that can be sourced by zsh configurations
    local fzf_config_dir="/usr/local/share/fzf"
    local fzf_config_file="$fzf_config_dir/fzf.zsh"
    
    if sudo -n true 2>/dev/null; then
        sudo mkdir -p "$fzf_config_dir"
        sudo tee "$fzf_config_file" > /dev/null << 'EOF'
# fzf fuzzy finder configuration
if [ -d "$HOME/.fzf/bin" ]; then
    export PATH="$HOME/.fzf/bin:$PATH"
fi

# fzf key bindings and completion (if available)
if [ -f "$HOME/.fzf/shell/key-bindings.zsh" ]; then
    source "$HOME/.fzf/shell/key-bindings.zsh"
fi

if [ -f "$HOME/.fzf/shell/completion.zsh" ]; then
    source "$HOME/.fzf/shell/completion.zsh"
fi
EOF
        sudo chmod 644 "$fzf_config_file"
        log_info "Created fzf configuration at $fzf_config_file"
        log_info "This will be automatically loaded by the zsh configuration system"
    else
        log_warn "Cannot create system-wide fzf configuration (no sudo access)"
    fi
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_fzf
fi
