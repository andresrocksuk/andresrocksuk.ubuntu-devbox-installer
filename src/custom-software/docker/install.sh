#!/bin/bash

# Docker Installation Script
# This script installs Docker Engine from the official repository

set -e

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$(cd "$SCRIPT_DIR/../../utils" && pwd)"

# Initialize framework availability
FRAMEWORK_AVAILABLE=false

# Try to source the installation framework
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
    FRAMEWORK_AVAILABLE=true
fi

# Source package manager utilities
if [ -f "$UTILS_DIR/package-manager.sh" ]; then
    source "$UTILS_DIR/package-manager.sh"
fi

# Source utilities - either from framework or standalone fallback
if [ "$FRAMEWORK_AVAILABLE" = "true" ]; then
    # Framework provides all utilities we need
    :
else
    # Fallback: source logger directly
    if [ -f "$UTILS_DIR/logger.sh" ]; then
        source "$UTILS_DIR/logger.sh"
    else
        # Minimal fallback logging functions
        log_info() { echo "[INFO] $1"; }
        log_error() { echo "[ERROR] $1" >&2; }
        log_success() { echo "[SUCCESS] $1"; }
        log_warn() { echo "[WARN] $1"; }
        log_debug() { 
            if [ "${LOG_LEVEL:-INFO}" = "DEBUG" ]; then
                echo "[DEBUG] $1" >&2
            fi
        }
    fi
fi

# Software-specific configuration
SOFTWARE_NAME="docker"
SOFTWARE_DESCRIPTION="Docker Engine"
COMMAND_NAME="docker"
VERSION_FLAG="--version"
DOCKER_GPG_URL="https://download.docker.com/linux/ubuntu/gpg"
DOCKER_REPO_BASE="https://download.docker.com/linux/ubuntu"

# Initialize the installation script if framework is available
if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v initialize_script >/dev/null 2>&1; then
    # Don't fail if initialization fails, just continue without framework
    initialize_script "$SOFTWARE_NAME" "$SOFTWARE_DESCRIPTION" || FRAMEWORK_AVAILABLE=false
fi

# Check for standalone execution
if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v handle_standalone_execution >/dev/null 2>&1; then
    if handle_standalone_execution "$SOFTWARE_NAME"; then
        log_info "Running in standalone mode with framework"
    fi
else
    # Fallback standalone detection and setup
    if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
        log_info "Running $SOFTWARE_NAME installation script in standalone mode"
    fi
fi

# Function to detect WSL environment
is_wsl_environment() {
    # Check for WSL indicators
    [ -f /proc/version ] && grep -q "Microsoft\|WSL" /proc/version
}

# Main installation function
install_docker() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # First, check for WSL Docker Desktop integration scenario before standard checks
    if command_exists "$COMMAND_NAME"; then
        local current_version
        if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v get_command_version >/dev/null 2>&1; then
            current_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "UNKNOWN")
        else
            current_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "UNKNOWN")
        fi
        
        # Remove any whitespace/newlines from version string
        current_version=$(echo "$current_version" | tr -d '[:space:]')
        
        # Check for WSL Docker Desktop integration scenario
        if [[ "$current_version" == *"UNKNOWN"* ]] && is_wsl_environment; then
            # Check if this is Docker Desktop WSL integration
            local docker_path
            docker_path=$(command -v docker 2>/dev/null || echo "")
            if [[ "$docker_path" == *"/mnt/c/"* ]] || [[ "$docker_path" == *"Program Files"* ]]; then
                log_info "Docker is available through Docker Desktop WSL integration"
                log_info "This provides Docker functionality but is not a native WSL installation"
                log_info "For native Docker installation, please ensure Docker Desktop WSL integration is disabled"
                return 0
            fi
        fi
        
        # If we have a valid version, log and return
        if [ "$current_version" != "UNKNOWN" ]; then
            log_info "$SOFTWARE_NAME is already installed (version: $current_version)"
            return 0
        fi
    fi
    
    # Validate GPG and repository URLs if framework available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$DOCKER_GPG_URL" >/dev/null; then
            log_error "Invalid Docker GPG URL"
            return 1
        fi
        if ! validate_and_sanitize_url "$DOCKER_REPO_BASE" >/dev/null; then
            log_error "Invalid Docker repository URL"
            return 1
        fi
    fi
    
    # Setup non-interactive environment for package installation
    setup_noninteractive_apt
    
    # Update package list
    log_info "Updating package list..."
    if ! safe_apt_update; then
        log_error "Failed to update package list"
        return 1
    fi
    
    # Install prerequisites
    log_info "Installing prerequisites..."
    local prerequisites=(
        "ca-certificates"
        "curl"
        "gnupg"
        "lsb-release"
    )
    
    if ! safe_apt_install "${prerequisites[@]}"; then
        log_error "Failed to install prerequisites"
        return 1
    fi
    
    # Add Docker's official GPG key
    log_info "Adding Docker GPG key..."
    sudo mkdir -p /etc/apt/keyrings
    
    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL "$DOCKER_GPG_URL" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
            log_error "Failed to add Docker GPG key"
            return 1
        fi
    else
        log_error "curl is required for Docker installation"
        return 1
    fi
    
    # Add Docker repository
    log_info "Adding Docker repository..."
    local arch
    arch=$(dpkg --print-architecture)
    local codename
    codename=$(lsb_release -cs)
    
    local repo_line="deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] $DOCKER_REPO_BASE $codename stable"
    
    if ! echo "$repo_line" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; then
        log_error "Failed to add Docker repository"
        return 1
    fi
    
    # Update package list with new repository
    log_info "Updating package list with Docker repository..."
    if ! safe_apt_update; then
        log_error "Failed to update package list after adding Docker repository"
        return 1
    fi
    
    # Install Docker Engine
    log_info "Installing Docker Engine..."
    local docker_packages=(
        "docker-ce"
        "docker-ce-cli"
        "containerd.io"
        "docker-buildx-plugin"
        "docker-compose-plugin"
    )
    
    if ! safe_apt_install "${docker_packages[@]}"; then
        log_error "Failed to install Docker packages"
        return 1
    fi
    
    # Start Docker service (with WSL consideration)
    log_info "Starting Docker service..."
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl start docker || log_info "Failed to start docker service via systemctl"
        sudo systemctl enable docker || log_info "Failed to enable docker service via systemctl"
    else
        log_info "Systemctl not available (normal in WSL)"
    fi
    
    # Add current user to docker group
    log_info "Adding user to docker group..."
    if ! sudo usermod -aG docker "$USER"; then
        log_warn "Failed to add user to docker group"
    fi
    
    # Start dockerd if not running (WSL specific)
    if ! pgrep dockerd >/dev/null 2>&1; then
        log_info "Starting dockerd daemon..."
        sudo dockerd > /dev/null 2>&1 &
        sleep 5
        if pgrep dockerd >/dev/null 2>&1; then
            log_debug "dockerd started in background"
        else
            log_warn "Failed to start dockerd daemon"
        fi
    fi
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "$COMMAND_NAME --help" "Docker"; then
            local installed_version
            installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            
            # Test Docker installation
            test_docker_installation
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local installed_version
            installed_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_success "$SOFTWARE_NAME installed successfully (version: $installed_version)"
            
            # Test Docker installation
            test_docker_installation
            return 0
        else
            log_error "$SOFTWARE_NAME installation verification failed"
            return 1
        fi
    fi
}

# Helper function to test Docker installation
test_docker_installation() {
    log_info "Testing Docker..."
    if sudo docker run --rm hello-world >/dev/null 2>&1; then
        log_success "Docker test successful"
    else
        log_info "Docker test failed, but installation appears successful"
        log_info "Note: You may need to restart your shell or run 'newgrp docker'"
    fi
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_docker
fi
