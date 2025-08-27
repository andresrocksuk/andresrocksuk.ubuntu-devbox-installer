#!/bin/bash

# Neovim Configuration Script
# This script creates a basic neovim configuration

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

# Standalone execution support
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    log_info "Running neovim configuration script in standalone mode"
fi

configure_neovim() {
    log_info "Configuring neovim with basic settings..."
    
    # Check if neovim is installed
    if ! command -v nvim >/dev/null 2>&1; then
        log_error "neovim is not installed. Please install neovim first."
        return 1
    fi
    
    # Create neovim config directory
    log_info "Creating neovim configuration directory..."
    mkdir -p ~/.config/nvim
    
    # Create basic init.vim if it doesn't exist
    if [ ! -f ~/.config/nvim/init.vim ]; then
        log_info "Creating basic init.vim configuration..."
        cat > ~/.config/nvim/init.vim << 'EOF'
" Basic Neovim Configuration
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent
set hlsearch
set incsearch
set ignorecase
set smartcase
set wrap
set linebreak
syntax enable
filetype plugin indent on
EOF
        log_info "Created basic neovim configuration at ~/.config/nvim/init.vim"
    else
        log_info "Neovim configuration already exists at ~/.config/nvim/init.vim"
    fi
    
    # Create skeleton configuration for new users
    create_skeleton_neovim_config
    
    return 0
}

create_skeleton_neovim_config() {
    log_info "Creating skeleton neovim configuration for new users..."
    
    # Create neovim config in skeleton directory
    sudo mkdir -p /etc/skel/.config/nvim
    
    if [ ! -f /etc/skel/.config/nvim/init.vim ]; then
        sudo tee /etc/skel/.config/nvim/init.vim > /dev/null << 'EOF'
" Basic Neovim Configuration
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent
set hlsearch
set incsearch
set ignorecase
set smartcase
set wrap
set linebreak
syntax enable
filetype plugin indent on
EOF
        log_info "Created skeleton neovim configuration for new users"
    else
        log_info "Skeleton neovim configuration already exists"
    fi
    
    # Fix ownership for existing users without neovim config
    for user_home in /home/*; do
        if [ -d "$user_home" ] && [ "$(basename "$user_home")" != "*" ]; then
            user_name=$(basename "$user_home")
            if [ ! -d "$user_home/.config/nvim" ] && id "$user_name" >/dev/null 2>&1; then
                sudo cp -r /etc/skel/.config "$user_home/" 2>/dev/null || true
                sudo chown -R "$user_name:$user_name" "$user_home/.config" 2>/dev/null || true
                log_info "Copied neovim configuration to existing user: $user_name"
            fi
        fi
    done
}

# Main execution
if configure_neovim; then
    log_info "Neovim configuration completed successfully"
    exit 0
else
    log_error "Neovim configuration failed"
    exit 1
fi
