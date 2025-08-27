#!/bin/bash

# docker installation script
# Installs Docker Engine

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

install_docker() {
    log_info "Installing Docker Engine..."
    
    # Check if already installed
    if command -v docker >/dev/null 2>&1; then
        local current_version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "Docker is already installed (version: $current_version)"
        return 0
    fi
    
    # Update package list
    log_info "Updating package list..."
    sudo apt-get update -qq
    
    # Install prerequisites
    log_info "Installing prerequisites..."
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    log_info "Adding Docker GPG key..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    log_info "Adding Docker repository..."
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list with new repository
    log_info "Updating package list with Docker repository..."
    sudo apt-get update -qq
    
    # Install Docker Engine
    log_info "Installing Docker Engine..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start Docker service
    log_info "Starting Docker service..."
    sudo systemctl start docker || log_info "Systemctl not available (normal in WSL)"
    sudo systemctl enable docker || log_info "Systemctl not available (normal in WSL)"
    
    # Add current user to docker group
    log_info "Adding user to docker group..."
    sudo usermod -aG docker $USER
    
    # Start dockerd if not running (WSL specific)
    if ! pgrep dockerd >/dev/null 2>&1; then
        log_info "Starting dockerd daemon..."
        sudo dockerd > /dev/null 2>&1 &
        sleep 5
    fi
    
    # Verify installation
    if command -v docker >/dev/null 2>&1; then
        local installed_version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "Docker installed successfully (version: $installed_version)"
        
        # Test run
        log_info "Testing Docker..."
        if sudo docker run --rm hello-world >/dev/null 2>&1; then
            log_success "Docker test successful"
        else
            log_info "Docker test failed, but installation appears successful"
            log_info "Note: You may need to restart your shell or run 'newgrp docker'"
        fi
        
        return 0
    else
        log_error "Docker installation verification failed"
        return 1
    fi
}

# Run installation
install_docker
