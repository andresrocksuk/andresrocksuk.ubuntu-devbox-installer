#!/bin/bash

# Go installation script
# Installs the latest Go version from official releases

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

install_golang() {
    log_info "Installing Go programming language..."
    
    # Check if already installed
    if command -v go >/dev/null 2>&1; then
        local current_version=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//' || echo "unknown")
        log_info "Go is already installed (version: $current_version)"
        
        # Check if it's a recent version (optional upgrade logic could go here)
        return 0
    fi
    
    # Get system architecture
    local arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv6l) arch="armv6l" ;;
        armv7l) arch="armv6l" ;;
        *) 
            log_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    
    # Get latest version from Go website
    log_info "Fetching latest Go version..."
    
    local latest_version
    if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -s https://go.dev/VERSION?m=text | head -n1)
    elif command -v wget >/dev/null 2>&1; then
        latest_version=$(wget -qO- https://go.dev/VERSION?m=text | head -n1)
    else
        log_error "Neither curl nor wget available for downloading"
        return 1
    fi
    
    if [ -z "$latest_version" ]; then
        log_error "Could not fetch latest Go version"
        return 1
    fi
    
    log_info "Latest Go version: $latest_version"
    
    # Construct download URL
    local filename="${latest_version}.linux-${arch}.tar.gz"
    local download_url="https://go.dev/dl/${filename}"
    local temp_file="/tmp/${filename}"
    
    log_info "Downloading Go from: $download_url"
    
    # Download Go
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$temp_file" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$temp_file" "$download_url"
    fi
    
    # Remove existing Go installation if present
    if [ -d "/usr/local/go" ]; then
        log_info "Removing existing Go installation..."
        sudo rm -rf /usr/local/go
    fi
    
    # Extract Go
    log_info "Installing Go to /usr/local/go..."
    sudo tar -C /usr/local -xzf "$temp_file"
    
    # Clean up
    rm -f "$temp_file"
    
    # Add Go to PATH in shell profiles using utility function
    if command -v add_path_to_profiles >/dev/null 2>&1; then
        add_path_to_profiles 'export PATH=$PATH:/usr/local/go/bin' "Go programming language" "/usr/local/go/bin"
    else
        # Fallback to direct configuration
        local go_path_export='export PATH=$PATH:/usr/local/go/bin'
        
        # Add to ~/.bashrc if it exists
        if [ -f ~/.bashrc ] && ! grep -q "/usr/local/go/bin" ~/.bashrc; then
            echo "" >> ~/.bashrc
            echo "# Go programming language" >> ~/.bashrc
            echo "$go_path_export" >> ~/.bashrc
            log_info "Added Go to ~/.bashrc"
        fi
        
        # Add to ~/.zshrc if it exists
        if [ -f ~/.zshrc ] && ! grep -q "/usr/local/go/bin" ~/.zshrc; then
            if grep -q "oh-my-zsh" ~/.zshrc; then
                # Use .zshrc.local for Oh-My-Zsh
                local zsh_config_file="$HOME/.zshrc.local"
                touch "$zsh_config_file"
                if ! grep -q "/usr/local/go/bin" "$zsh_config_file"; then
                    echo "" >> "$zsh_config_file"
                    echo "# Go programming language" >> "$zsh_config_file"
                    echo "$go_path_export" >> "$zsh_config_file"
                    log_info "Added Go to ~/.zshrc.local"
                fi
            else
                echo "" >> ~/.zshrc
                echo "# Go programming language" >> ~/.zshrc
                echo "$go_path_export" >> ~/.zshrc
                log_info "Added Go to ~/.zshrc"
            fi
        fi
        
        # Add to ~/.profile if it exists
        if [ -f ~/.profile ] && ! grep -q "/usr/local/go/bin" ~/.profile; then
            echo "" >> ~/.profile
            echo "# Go programming language" >> ~/.profile
            echo "$go_path_export" >> ~/.profile
            log_info "Added Go to ~/.profile"
        fi
    fi
    
    # Set up GOPATH and GOBIN using utility function
    if command -v add_env_to_profiles >/dev/null 2>&1; then
        local go_env_setup='export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOBIN'
        add_env_to_profiles "$go_env_setup" "Go environment" "GOPATH"
    else
        # Fallback to direct configuration
        local go_env_setup='
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOBIN'
        
        # Add GOPATH setup to shell profiles
        if [ -f ~/.bashrc ] && ! grep -q "GOPATH" ~/.bashrc; then
            echo "$go_env_setup" >> ~/.bashrc
            log_info "Added GOPATH configuration to ~/.bashrc"
        fi
        
        if [ -f ~/.zshrc ] && ! grep -q "GOPATH" ~/.zshrc; then
            if grep -q "oh-my-zsh" ~/.zshrc; then
                # Use .zshrc.local for Oh-My-Zsh
                local zsh_config_file="$HOME/.zshrc.local"
                touch "$zsh_config_file"
                if ! grep -q "GOPATH" "$zsh_config_file"; then
                    echo "$go_env_setup" >> "$zsh_config_file"
                    log_info "Added GOPATH configuration to ~/.zshrc.local"
                fi
            else
                echo "$go_env_setup" >> ~/.zshrc
                log_info "Added GOPATH configuration to ~/.zshrc"
            fi
        fi
    fi
    
    # Create GOPATH directory
    mkdir -p ~/go/{bin,src,pkg}
    log_info "Created Go workspace directories"
    
    # Update current PATH for verification
    export PATH=$PATH:/usr/local/go/bin
    
    # Verify installation
    if command -v go >/dev/null 2>&1; then
        local installed_version=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//' || echo "unknown")
        log_success "Go installed successfully (version: $installed_version)"
        
        # Test Go installation
        log_info "Testing Go installation..."
        go version && log_success "Go test successful"
        
        # Show Go environment
        log_info "Go environment:"
        go env GOPATH GOROOT
        
        return 0
    else
        log_error "Go installation verification failed"
        return 1
    fi
}

# Run installation
install_golang
