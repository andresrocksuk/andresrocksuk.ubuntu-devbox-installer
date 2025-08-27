#!/bin/bash

# fzf installation script
# Installs fzf (fuzzy finder) from GitHub

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
fi

# Source environment setup utilities
if [ -f "$UTILS_DIR/environment-setup.sh" ]; then
    source "$UTILS_DIR/environment-setup.sh"
fi

install_fzf() {
    log_info "Installing fzf (fuzzy finder)..."
    
    # Check if already installed
    if command -v fzf >/dev/null 2>&1; then
        local current_version=$(fzf --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "fzf is already installed (version: $current_version)"
        return 0
    fi
    
    # Clone fzf repository
    local fzf_dir="$HOME/.fzf"
    
    if [ -d "$fzf_dir" ]; then
        log_info "fzf directory already exists, updating..."
        cd "$fzf_dir"
        git pull
    else
        log_info "Cloning fzf repository..."
        git clone --depth 1 https://github.com/junegunn/fzf.git "$fzf_dir"
        cd "$fzf_dir"
    fi
    
    # Install fzf
    log_info "Installing fzf..."
    ./install --all --no-update-rc
    
    # Add to PATH if not already there
    if ! command -v fzf >/dev/null 2>&1; then
        log_info "Adding fzf to PATH..."
        
        # Use environment setup utility if available
        if command -v add_to_path >/dev/null 2>&1; then
            add_to_path "$HOME/.fzf/bin" "fzf binary directory"
            
            # Try to install system-wide if possible
            if [ -f "$HOME/.fzf/bin/fzf" ]; then
                install_binary_system_wide "$HOME/.fzf/bin/fzf" "fzf" "/usr/local/bin"
            fi
            
            # Update skeleton files for new users
            update_skeleton_files "export PATH=\"\$HOME/.fzf/bin:\$PATH\"" "fzf fuzzy finder PATH"
            
        else
            # Fallback to original method
            setup_fzf_environment_fallback
        fi
        
        # Export for current session
        export PATH="$HOME/.fzf/bin:$PATH"
    fi
    
    # Verify installation
    if command -v fzf >/dev/null 2>&1 || [ -f "$HOME/.fzf/bin/fzf" ]; then
        local fzf_cmd="fzf"
        if ! command -v fzf >/dev/null 2>&1; then
            fzf_cmd="$HOME/.fzf/bin/fzf"
        fi
        
        local installed_version=$($fzf_cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "fzf installed successfully (version: $installed_version)"
        
        # Test run
        log_info "Testing fzf..."
        echo "test" | $fzf_cmd --filter="test" >/dev/null 2>&1 && log_success "fzf test successful"
        
        return 0
    else
        log_error "fzf installation verification failed"
        return 1
    fi
}

# Run installation
install_fzf

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
    # This integrates better with the zsh configuration management
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

# Run installation
install_fzf
