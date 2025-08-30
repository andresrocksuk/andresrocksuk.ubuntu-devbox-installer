#!/bin/bash

# Go installation script
# Installs the latest Go version from official releases

set -e

# Define software metadata
SOFTWARE_NAME="golang"
SOFTWARE_DESCRIPTION="Go programming language"
COMMAND_NAME="go"
VERSION_FLAG="version"
GITHUB_REPO=""  # Not used for Go official downloads

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

install_golang() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if already installed (using framework if available)
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_already_installed >/dev/null 2>&1; then
        if check_already_installed "$COMMAND_NAME" "$VERSION_FLAG"; then
            return 0
        fi
    else
        # Fallback: manual check
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local current_version=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//' || echo "unknown")
            log_info "$SOFTWARE_DESCRIPTION is already installed (version: $current_version)"
            return 0
        fi
    fi
    
    # Get system architecture using framework if available
    local arch
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v get_system_architecture >/dev/null 2>&1; then
        arch=$(get_system_architecture)
        # Convert to Go's architecture naming
        case $arch in
            amd64|arm64) ;; # Already correct
            armv6l|armv7l) arch="armv6l" ;;
            *) 
                log_error "Unsupported architecture: $arch"
                return 1
                ;;
        esac
    else
        # Fallback architecture detection
        arch=$(uname -m)
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
    fi
    
    # Get latest version from Go website
    log_info "Fetching latest Go version..."
    
    local latest_version
    local version_url="https://go.dev/VERSION?m=text"
    
    # Validate URL using security helpers if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$version_url" >/dev/null; then
            log_error "Invalid version URL"
            return 1
        fi
    fi
    
    if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -s "$version_url" | head -n1)
    elif command -v wget >/dev/null 2>&1; then
        latest_version=$(wget -qO- "$version_url" | head -n1)
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
    
    # Validate download URL if framework available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$download_url" >/dev/null; then
            log_error "Invalid download URL"
            return 1
        fi
    fi
    
    log_info "Downloading Go from: $download_url"
    
    # Create secure temporary directory for downloads
    local temp_dir
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v create_secure_temp_dir >/dev/null 2>&1; then
        temp_dir=$(create_secure_temp_dir "golang")
    else
        temp_dir=$(mktemp -d)
        chmod 700 "$temp_dir"
    fi
    
    local temp_file="$temp_dir/$filename"
    
    # Download Go using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v download_file >/dev/null 2>&1; then
        if ! download_file "$download_url" "$temp_file"; then
            log_error "Failed to download Go archive"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        # Fallback download
        if command -v curl >/dev/null 2>&1; then
            if ! curl -L -o "$temp_file" "$download_url"; then
                log_error "Download failed with curl"
                rm -rf "$temp_dir"
                return 1
            fi
        elif command -v wget >/dev/null 2>&1; then
            if ! wget -O "$temp_file" "$download_url"; then
                log_error "Download failed with wget"
                rm -rf "$temp_dir"
                return 1
            fi
        fi
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
    rm -rf "$temp_dir"
    
    # Setup Go environment
    setup_go_environment
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        # Update current PATH for verification
        export PATH=$PATH:/usr/local/go/bin
        
        if verify_installation "$COMMAND_NAME" "go version" "Go"; then
            local installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null | awk '{print $3}' | sed 's/go//' || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            show_go_usage_info
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        # Update current PATH for verification
        export PATH=$PATH:/usr/local/go/bin
        
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local installed_version=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//' || echo "unknown")
            log_success "$SOFTWARE_DESCRIPTION installed successfully (version: $installed_version)"
            
            # Test Go installation
            log_info "Testing Go installation..."
            go version && log_success "Go test successful"
            
            # Show Go environment
            log_info "Go environment:"
            go env GOPATH GOROOT
            
            show_go_usage_info
            return 0
        else
            log_error "$SOFTWARE_DESCRIPTION installation verification failed"
            return 1
        fi
    fi
}

# Helper function to set up Go environment
setup_go_environment() {
    log_info "Setting up Go environment..."
    
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
}

# Helper function to show usage information
show_go_usage_info() {
    log_info "To get started with Go:"
    log_info "  go version                 # Check Go version"
    log_info "  go mod init <module>       # Initialize a new module"
    log_info "  go build                   # Build the current package"
    log_info "  go run <file.go>          # Run a Go file"
    log_info "  go test                    # Run tests"
    log_info "  go get <package>           # Download and install packages"
    log_info ""
    log_info "Environment:"
    log_info "  GOPATH=$HOME/go           # Go workspace"
    log_info "  GOBIN=$HOME/go/bin        # Go binaries"
    log_info ""
    log_info "Documentation: https://golang.org/doc/"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_golang
fi
