#!/bin/bash

# docker-compose installation script
# Installs Docker Compose

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

install_docker_compose() {
    log_info "Installing Docker Compose..."
    
    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed. Please install Docker first."
        return 1
    fi
    
    # Check if docker-compose is already installed
    if command -v docker-compose >/dev/null 2>&1; then
        local current_version=$(docker-compose --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "docker-compose is already installed (version: $current_version)"
        return 0
    fi
    
    # Check if Docker Compose plugin is available (newer Docker installations)
    if docker compose version >/dev/null 2>&1; then
        local plugin_version=$(docker compose version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "Docker Compose plugin is available (version: $plugin_version)"
        
        # Create docker-compose alias for compatibility
        log_info "Creating docker-compose alias..."
        cat > /tmp/docker-compose-wrapper << 'EOF'
#!/bin/bash
exec docker compose "$@"
EOF
        chmod +x /tmp/docker-compose-wrapper
        sudo mv /tmp/docker-compose-wrapper /usr/local/bin/docker-compose
        
        log_success "Docker Compose alias created successfully"
        return 0
    fi
    
    # Get latest release from GitHub
    log_info "Fetching latest Docker Compose release..."
    local repo="docker/compose"
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    
    local release_info
    if command -v curl >/dev/null 2>&1; then
        release_info=$(curl -s "$api_url")
    elif command -v wget >/dev/null 2>&1; then
        release_info=$(wget -qO- "$api_url")
    else
        log_error "Neither curl nor wget available for downloading"
        return 1
    fi
    
    # Parse release information
    local tag_name=$(echo "$release_info" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    local version=$(echo "$tag_name" | sed 's/^v//')
    
    if [ -z "$version" ]; then
        log_error "Could not determine latest Docker Compose version"
        return 1
    fi
    
    log_info "Latest Docker Compose version: $version"
    
    # Download Docker Compose
    local download_url="https://github.com/docker/compose/releases/download/${tag_name}/docker-compose-$(uname -s)-$(uname -m)"
    local install_path="/usr/local/bin/docker-compose"
    
    log_info "Downloading Docker Compose..."
    if command -v curl >/dev/null 2>&1; then
        sudo curl -L "$download_url" -o "$install_path"
    elif command -v wget >/dev/null 2>&1; then
        sudo wget -O "$install_path" "$download_url"
    fi
    
    # Make executable
    sudo chmod +x "$install_path"
    
    # Verify installation
    if command -v docker-compose >/dev/null 2>&1; then
        local installed_version=$(docker-compose --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "Docker Compose installed successfully (version: $installed_version)"
        
        # Test run
        log_info "Testing Docker Compose..."
        docker-compose --help >/dev/null 2>&1 && log_success "Docker Compose test successful"
        
        return 0
    else
        log_error "Docker Compose installation verification failed"
        return 1
    fi
}

# Run installation
install_docker_compose
