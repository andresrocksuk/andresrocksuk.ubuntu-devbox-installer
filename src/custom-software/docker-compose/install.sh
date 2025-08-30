#!/bin/bash

# Docker Compose Installation Script
# Installs Docker Compose

# Get script directory for reliable path resolution
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../../utils"

# Source installation framework
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
else
    echo "Error: installation-framework.sh not found at $UTILS_DIR/installation-framework.sh"
    exit 1
fi

# Enable error handling
set -e

# Main installation function
install_docker_compose() {
    log_section "Installing Docker Compose"
    
    # Check if Docker is installed
    if ! command_exists "docker"; then
        log_error "Docker is not installed. Please install Docker first."
        return 1
    fi
    
    # Check for WSL Docker Desktop integration scenario
    local docker_path
    docker_path=$(command -v docker 2>/dev/null || echo "")
    if [[ "$docker_path" == *"/mnt/c/"* ]] || [[ "$docker_path" == *"Program Files"* ]]; then
        log_info "Docker Desktop WSL integration detected"
        log_info "Docker Compose functionality is typically available through Docker Desktop"
        log_info "To verify: try running 'docker compose version' in your terminal"
        log_info "If Docker Desktop integration is working properly, docker-compose should be available"
        return 0
    fi
    
    # Check if docker-compose is already installed
    if command_exists "docker-compose"; then
        local current_version
        current_version=$(get_command_version "docker-compose" "--version")
        if [ "$current_version" != "NOT_INSTALLED" ] && [ "$current_version" != "UNKNOWN" ]; then
            log_info "Docker Compose already installed: $current_version"
            return 0
        fi
    fi
    
    # Check if Docker Compose plugin is available (newer Docker installations)
    if docker compose version >/dev/null 2>&1; then
        local plugin_version
        plugin_version=$(docker compose version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "Docker Compose plugin available: $plugin_version"
        
        # Create docker-compose alias for compatibility
        log_info "Creating docker-compose alias..."
        cat > /tmp/docker-compose-wrapper << 'EOF'
#!/bin/bash
exec docker compose "$@"
EOF
        chmod +x /tmp/docker-compose-wrapper
        sudo mv /tmp/docker-compose-wrapper /usr/local/bin/docker-compose
        
        if verify_installation "docker-compose" "any"; then
            log_success "Docker Compose alias created successfully"
            return 0
        else
            log_error "Failed to create Docker Compose alias"
            return 1
        fi
    fi
    
    # Get latest release from GitHub
    log_info "Fetching latest Docker Compose release..."
    local repo="docker/compose"
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    
    local release_info
    if command_exists "curl"; then
        release_info=$(curl -s "$api_url")
    elif command_exists "wget"; then
        release_info=$(wget -qO- "$api_url")
    else
        log_error "Neither curl nor wget available for downloading"
        return 1
    fi
    
    # Parse release information
    local tag_name
    tag_name=$(echo "$release_info" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    local version
    version=$(echo "$tag_name" | sed 's/^v//')
    
    if [ -z "$version" ]; then
        log_error "Could not determine latest Docker Compose version"
        return 1
    fi
    
    log_info "Latest Docker Compose version: $version"
    
    # Download Docker Compose
    local download_url="https://github.com/docker/compose/releases/download/${tag_name}/docker-compose-$(uname -s)-$(uname -m)"
    local install_path="/usr/local/bin/docker-compose"
    
    log_info "Downloading Docker Compose..."
    if command_exists "curl"; then
        sudo curl -L "$download_url" -o "$install_path"
    elif command_exists "wget"; then
        sudo wget -O "$install_path" "$download_url"
    fi
    
    # Make executable
    sudo chmod +x "$install_path"
    
    # Verify installation
    if verify_installation "docker-compose" "any"; then
        log_success "Docker Compose installed successfully"
        
        # Test run
        log_info "Testing Docker Compose..."
        if docker-compose --help >/dev/null 2>&1; then
            log_success "Docker Compose test successful"
        fi
        return 0
    else
        log_error "Docker Compose installation verification failed"
        return 1
    fi
}

# Execute installation
install_docker_compose "$@"
