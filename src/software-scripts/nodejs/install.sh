#!/bin/bash

# Node.js LTS installation script
# Installs Node.js LTS using NodeSource repository

set -e

# Define software metadata
SOFTWARE_NAME="nodejs"
SOFTWARE_DESCRIPTION="Node.js JavaScript runtime"
COMMAND_NAME="node"
VERSION_FLAG="--version"
GITHUB_REPO=""  # Not used for NodeSource installation

# Get script directory and source framework
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/../utils"

# Try to source the installation framework
FRAMEWORK_AVAILABLE="false"
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
    FRAMEWORK_AVAILABLE="true"
fi

# Initialize script using framework if available
if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v initialize_script >/dev/null 2>&1; then
    initialize_script "$SOFTWARE_NAME" "$SOFTWARE_DESCRIPTION" "$COMMAND_NAME"
else
    # Fallback initialization
    source "$UTILS_DIR/logger.sh" 2>/dev/null || {
        log_info() { echo "[INFO] $1"; }
        log_error() { echo "[ERROR] $1"; }
        log_success() { echo "[SUCCESS] $1"; }
        log_debug() { echo "[DEBUG] $1"; }
        log_warn() { echo "[WARN] $1"; }
    }
    
    # Source shell configuration utilities if available
    if [ -f "$UTILS_DIR/shell-config.sh" ]; then
        source "$UTILS_DIR/shell-config.sh"
    fi
fi

install_nodejs() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if already installed (using framework if available)
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_already_installed >/dev/null 2>&1; then
        if check_already_installed "$COMMAND_NAME" "$VERSION_FLAG"; then
            # Also check npm availability
            if command -v npm >/dev/null 2>&1; then
                local npm_version=$(npm --version 2>/dev/null || echo "unknown")
                log_info "npm is available (version: $npm_version)"
            fi
            return 0
        fi
    else
        # Fallback: manual check
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local current_version=$(node --version 2>/dev/null | sed 's/^v//' || echo "unknown")
            log_info "$SOFTWARE_NAME is already installed (version: $current_version)"
            
            # Check if npm is also available
            if command -v npm >/dev/null 2>&1; then
                local npm_version=$(npm --version 2>/dev/null || echo "unknown")
                log_info "npm is available (version: $npm_version)"
            fi
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
    local api_url="https://nodejs.org/dist/index.json"
    
    # Validate URL using security helpers if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$api_url" >/dev/null; then
            log_error "Invalid API URL"
            return 1
        fi
    fi
    
    if command -v curl >/dev/null 2>&1; then
        lts_version=$(curl -s "$api_url" | grep -oE '"version":"v[0-9]+\.[0-9]+\.[0-9]+"' | grep -E 'v(18|20|22)\.' | head -n1 | sed 's/"version":"v\([0-9]*\)\..*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        lts_version=$(wget -qO- "$api_url" | grep -oE '"version":"v[0-9]+\.[0-9]+\.[0-9]+"' | grep -E 'v(18|20|22)\.' | head -n1 | sed 's/"version":"v\([0-9]*\)\..*/\1/')
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
    local setup_script_url="https://deb.nodesource.com/setup_${lts_version}.x"
    
    # Validate setup script URL if framework available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$setup_script_url" >/dev/null; then
            log_error "Invalid setup script URL"
            return 1
        fi
    fi
    
    # Create secure temporary directory for setup script
    local temp_dir
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v create_secure_temp_dir >/dev/null 2>&1; then
        temp_dir=$(create_secure_temp_dir "nodejs")
    else
        temp_dir=$(mktemp -d)
        chmod 700 "$temp_dir"
    fi
    
    local setup_script="$temp_dir/nodesource_setup.sh"
    
    # Download setup script using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v download_file >/dev/null 2>&1; then
        if ! download_file "$setup_script_url" "$setup_script"; then
            log_error "Failed to download NodeSource setup script"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        # Fallback download
        if command -v curl >/dev/null 2>&1; then
            if ! curl -fsSL -o "$setup_script" "$setup_script_url"; then
                log_error "Setup script download failed with curl"
                rm -rf "$temp_dir"
                return 1
            fi
        elif command -v wget >/dev/null 2>&1; then
            if ! wget -O "$setup_script" "$setup_script_url"; then
                log_error "Setup script download failed with wget"
                rm -rf "$temp_dir"
                return 1
            fi
        fi
    fi
    
    # Run the setup script
    sudo bash "$setup_script"
    
    # Clean up setup script
    rm -rf "$temp_dir"
    
    # Install Node.js
    log_info "Installing Node.js and npm..."
    sudo apt-get update
    sudo apt-get install -y nodejs
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "node -e \"console.log('Node.js test successful!')\"" "Node.js" && 
           verify_installation "npm" "npm --version" "npm"; then
            
            local node_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
            local npm_version=$(npm --version 2>/dev/null || echo "unknown")
            
            log_installation_result "$SOFTWARE_NAME" "success" "$node_version"
            log_info "npm installed successfully (version: $npm_version)"
            setup_npm_environment
            install_global_packages
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$COMMAND_NAME" >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
            local node_version=$(node --version 2>/dev/null | sed 's/^v//' || echo "unknown")
            local npm_version=$(npm --version 2>/dev/null || echo "unknown")
            
            log_success "$SOFTWARE_NAME installed successfully (version: $node_version)"
            log_success "npm installed successfully (version: $npm_version)"
            
            # Test installations
            log_info "Testing Node.js installation..."
            node -e "console.log('Node.js is working!')" && log_success "Node.js test successful"
            
            log_info "Testing npm installation..."
            npm --version >/dev/null && log_success "npm test successful"
            
            setup_npm_environment
            install_global_packages
            return 0
        else
            log_error "$SOFTWARE_NAME installation verification failed"
            return 1
        fi
    fi
}

# Helper function to set up npm environment
setup_npm_environment() {
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
}

# Helper function to install global npm packages
install_global_packages() {
    log_info "Installing useful global npm packages..."
    
    # List of packages to install
    local packages=(
        "yarn"
        "typescript"
        "@angular/cli"
        "create-react-app"
        "nodemon"
    )
    
    for package in "${packages[@]}"; do
        log_info "Installing $package..."
        if npm install -g "$package" >/dev/null 2>&1; then
            log_success "$package installed successfully"
        else
            log_warn "Failed to install $package"
        fi
    done
    
    log_success "Global npm packages installation completed"
    show_nodejs_usage_info
}

# Helper function to show usage information
show_nodejs_usage_info() {
    log_info "To get started with Node.js:"
    log_info "  node --version             # Check Node.js version"
    log_info "  npm --version              # Check npm version"
    log_info "  npm init                   # Initialize a new project"
    log_info "  npm install <package>      # Install a package"
    log_info "  npm run <script>           # Run a script"
    log_info ""
    log_info "Available global tools:"
    log_info "  yarn                       # Alternative package manager"
    log_info "  tsc                        # TypeScript compiler"
    log_info "  ng                         # Angular CLI"
    log_info "  create-react-app           # React app generator"
    log_info "  nodemon                    # Development server with auto-restart"
    log_info ""
    log_info "Documentation: https://nodejs.org/docs/"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_nodejs
fi
