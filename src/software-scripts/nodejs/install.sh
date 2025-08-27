#!/bin/bash

# Node.js LTS installation script
# Installs Node.js LTS using NodeSource repository

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

# Source shell configuration utilities if available
if [ -f "$UTILS_DIR/shell-config.sh" ]; then
    source "$UTILS_DIR/shell-config.sh"
fi

install_nodejs() {
    log_info "Installing Node.js LTS..."
    
    # Check if already installed
    if command -v node >/dev/null 2>&1; then
        local current_version=$(node --version 2>/dev/null | sed 's/^v//' || echo "unknown")
        log_info "Node.js is already installed (version: $current_version)"
        
        # Check if npm is also available
        if command -v npm >/dev/null 2>&1; then
            local npm_version=$(npm --version 2>/dev/null || echo "unknown")
            log_info "npm is available (version: $npm_version)"
            return 0
        fi
    fi
    
    # Install prerequisites
    log_info "Installing prerequisites..."
    sudo apt-get update
    sudo apt-get install -y curl gnupg2 software-properties-common
    
    # Get the latest LTS version number
    log_info "Fetching latest LTS version information..."
    
    local lts_version
    if command -v curl >/dev/null 2>&1; then
        lts_version=$(curl -s https://nodejs.org/dist/index.json | grep -oE '"version":"v[0-9]+\.[0-9]+\.[0-9]+"' | grep -E 'v(18|20|22)\.' | head -n1 | sed 's/"version":"v\([0-9]*\)\..*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        lts_version=$(wget -qO- https://nodejs.org/dist/index.json | grep -oE '"version":"v[0-9]+\.[0-9]+\.[0-9]+"' | grep -E 'v(18|20|22)\.' | head -n1 | sed 's/"version":"v\([0-9]*\)\..*/\1/')
    else
        # Fallback to a known LTS version
        lts_version="20"
        log_info "Could not fetch version info, using Node.js 20.x LTS"
    fi
    
    if [ -z "$lts_version" ]; then
        lts_version="20"
        log_info "Could not determine LTS version, defaulting to Node.js 20.x"
    fi
    
    log_info "Installing Node.js ${lts_version}.x LTS..."
    
    # Add NodeSource repository
    log_info "Adding NodeSource repository..."
    
    # Download and execute NodeSource setup script
    local setup_script="/tmp/nodesource_setup.sh"
    
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "https://deb.nodesource.com/setup_${lts_version}.x" -o "$setup_script"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$setup_script" "https://deb.nodesource.com/setup_${lts_version}.x"
    fi
    
    # Run the setup script
    sudo bash "$setup_script"
    
    # Clean up setup script
    rm -f "$setup_script"
    
    # Install Node.js
    log_info "Installing Node.js and npm..."
    sudo apt-get update
    sudo apt-get install -y nodejs
    
    # Verify installation
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        local node_version=$(node --version 2>/dev/null | sed 's/^v//' || echo "unknown")
        local npm_version=$(npm --version 2>/dev/null || echo "unknown")
        
        log_success "Node.js installed successfully (version: $node_version)"
        log_success "npm installed successfully (version: $npm_version)"
        
        # Test Node.js installation
        log_info "Testing Node.js installation..."
        node -e "console.log('Node.js is working!')" && log_success "Node.js test successful"
        
        # Test npm installation
        log_info "Testing npm installation..."
        npm --version >/dev/null && log_success "npm test successful"
        
        # Set up npm global directory for user
        log_info "Configuring npm global directory..."
        mkdir -p ~/.npm-global
        npm config set prefix '~/.npm-global'
        
        # Add npm global bin to shell profiles using utility function
        if command -v add_path_to_profiles >/dev/null 2>&1; then
            add_path_to_profiles 'export PATH=~/.npm-global/bin:$PATH' "npm global packages" "npm-global"
        else
            # Fallback to direct configuration
            local npm_path_export='export PATH=~/.npm-global/bin:$PATH'
            
            # Add to shell profiles
            if [ -f ~/.bashrc ] && ! grep -q "npm-global" ~/.bashrc; then
                echo "" >> ~/.bashrc
                echo "# npm global packages" >> ~/.bashrc
                echo "$npm_path_export" >> ~/.bashrc
                log_info "Added npm global path to ~/.bashrc"
            fi
            
            if [ -f ~/.zshrc ] && ! grep -q "npm-global" ~/.zshrc; then
                if grep -q "oh-my-zsh" ~/.zshrc; then
                    # Use .zshrc.local for Oh-My-Zsh
                    local zsh_config_file="$HOME/.zshrc.local"
                    touch "$zsh_config_file"
                    if ! grep -q "npm-global" "$zsh_config_file"; then
                        echo "" >> "$zsh_config_file"
                        echo "# npm global packages" >> "$zsh_config_file"
                        echo "$npm_path_export" >> "$zsh_config_file"
                        log_info "Added npm global path to ~/.zshrc.local"
                    fi
                else
                    echo "" >> ~/.zshrc
                    echo "# npm global packages" >> ~/.zshrc
                    echo "$npm_path_export" >> ~/.zshrc
                    log_info "Added npm global path to ~/.zshrc"
                fi
            fi
            
            if [ -f ~/.profile ] && ! grep -q "npm-global" ~/.profile; then
                echo "" >> ~/.profile
                echo "# npm global packages" >> ~/.profile
                echo "$npm_path_export" >> ~/.profile
                log_info "Added npm global path to ~/.profile"
            fi
        fi
        
        # Update current PATH
        export PATH=~/.npm-global/bin:$PATH
        
        # Install some useful global packages
        log_info "Installing useful global npm packages..."
        npm install -g yarn
        npm install -g typescript
        npm install -g @angular/cli
        npm install -g create-react-app
        npm install -g nodemon
        
        log_success "Global npm packages installed"
        
        return 0
    else
        log_error "Node.js installation verification failed"
        return 1
    fi
}

# Run installation
install_nodejs
