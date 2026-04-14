#!/bin/bash

# Docker Installation Script
# This script installs Docker Engine from the official repository
# Supports three execution contexts:
#   - WSL: Docker Desktop integration or native Docker in WSL
#   - Native Linux (VM/bare metal): Full Docker Engine with systemd service
#   - Container (Docker-in-Docker): Docker Engine without systemd

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

# Source environment detector
if [ -f "$UTILS_DIR/environment-detector.sh" ]; then
    source "$UTILS_DIR/environment-detector.sh"
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

# Fallback environment detection if environment-detector.sh was not sourced
if ! command -v get_environment_type >/dev/null 2>&1; then
    is_wsl_environment() {
        [ -f /proc/version ] && grep -qi "Microsoft\|WSL" /proc/version 2>/dev/null
    }
    is_container_environment() {
        [ -f /.dockerenv ] || ([ -f /proc/1/cgroup ] && grep -qi "docker\|containerd\|lxc" /proc/1/cgroup 2>/dev/null)
    }
    is_native_environment() {
        ! is_wsl_environment && ! is_container_environment
    }
    has_systemd() {
        command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]
    }
    is_docker_desktop_integration() {
        is_wsl_environment || return 1
        local dp
        dp=$(command -v docker 2>/dev/null || echo "")
        [[ "$dp" == *"/mnt/c/"* ]] || [[ "$dp" == *"Program Files"* ]]
    }
    get_environment_type() {
        if is_wsl_environment; then echo "wsl"
        elif is_container_environment; then echo "container"
        else echo "native"; fi
    }
fi

# Main installation function
install_docker() {
    local env_type
    env_type=$(get_environment_type)
    log_info "Installing $SOFTWARE_DESCRIPTION... (environment: $env_type)"

    # Log environment details if detector is available
    if command -v log_environment_info >/dev/null 2>&1; then
        log_environment_info
    fi

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
        if [[ "$current_version" == *"UNKNOWN"* ]] && is_docker_desktop_integration; then
            log_info "Docker is available through Docker Desktop WSL integration"
            log_info "This provides Docker functionality but is not a native WSL installation"
            log_info "For native Docker installation, please ensure Docker Desktop WSL integration is disabled"
            return 0
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
    
    # Configure Docker service based on environment type
    configure_docker_service "$env_type"
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "$COMMAND_NAME --help" "Docker"; then
            local installed_version
            installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            
            # Test Docker installation
            test_docker_installation "$env_type"
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
            test_docker_installation "$env_type"
            return 0
        else
            log_error "$SOFTWARE_NAME installation verification failed"
            return 1
        fi
    fi
}

# Configure Docker service based on detected environment
configure_docker_service() {
    local env_type="${1:-native}"

    # Ensure the docker group exists
    if ! getent group docker >/dev/null 2>&1; then
        log_info "Creating docker group..."
        sudo groupadd docker || log_warn "Failed to create docker group"
    fi

    # Add current user to docker group
    log_info "Adding user '$USER' to docker group..."
    if ! sudo usermod -aG docker "$USER"; then
        log_warn "Failed to add user to docker group"
    fi

    case "$env_type" in
        native)
            configure_docker_native
            ;;
        wsl)
            configure_docker_wsl
            ;;
        container)
            configure_docker_container
            ;;
        *)
            log_warn "Unknown environment type: $env_type, falling back to native configuration"
            configure_docker_native
            ;;
    esac
}

# Configure Docker on native Linux (VM or bare metal)
configure_docker_native() {
    log_info "Configuring Docker for native Linux environment..."

    if has_systemd; then
        log_info "Enabling and starting Docker via systemd..."
        if ! sudo systemctl enable docker; then
            log_warn "Failed to enable docker service"
        fi
        if ! sudo systemctl enable containerd; then
            log_warn "Failed to enable containerd service"
        fi
        if ! sudo systemctl start docker; then
            log_error "Failed to start docker service via systemctl"
            return 1
        fi
        log_success "Docker service started and enabled via systemd"
    else
        log_warn "Systemd not available on native Linux; starting dockerd manually"
        start_dockerd_background
    fi

    # Ensure docker socket has correct permissions
    ensure_docker_socket_permissions
}

# Configure Docker in WSL environment
configure_docker_wsl() {
    log_info "Configuring Docker for WSL environment..."

    # Try systemd first (WSL2 with systemd support)
    if has_systemd; then
        log_info "WSL2 with systemd detected, using systemd for Docker..."
        if ! sudo systemctl enable docker; then
            log_warn "Failed to enable docker service in WSL"
        fi
        if ! sudo systemctl start docker; then
            log_warn "Failed to start docker via systemctl in WSL, falling back to manual start"
            start_dockerd_background
        else
            log_success "Docker service started via systemd in WSL"
        fi
    else
        log_info "Systemd not available in WSL, starting dockerd manually..."
        start_dockerd_background
    fi

    ensure_docker_socket_permissions
}

# Configure Docker inside a container (Docker-in-Docker)
configure_docker_container() {
    log_info "Configuring Docker for container environment (Docker-in-Docker)..."

    # During image build, starting dockerd won't persist across layers.
    # Install a shell autostart script that starts dockerd when an interactive
    # session opens. This avoids requiring a specific ENTRYPOINT and gracefully
    # does nothing if Docker was not installed.
    install_docker_autostart

    log_info "Docker-in-Docker configured. dockerd will auto-start on interactive shell login."
}

# Install a shell profile script that auto-starts dockerd in interactive
# container sessions.  Works via /etc/profile.d (login shells) and
# /etc/bash.bashrc (non-login interactive shells such as "docker run -it bash").
install_docker_autostart() {
    local autostart_path="/etc/profile.d/docker-autostart.sh"

    log_info "Installing Docker autostart script at $autostart_path..."

    cat << 'AUTOSTART_EOF' | sudo tee "$autostart_path" > /dev/null
#!/bin/bash
# Auto-start Docker daemon for Docker-in-Docker containers.
# Sourced by interactive shells; does nothing if Docker is not installed.

# Guard: only for interactive shells
[[ $- != *i* ]] && return

# Guard: only if dockerd binary exists
command -v dockerd >/dev/null 2>&1 || return

# Guard: skip if dockerd is already running
pgrep -x dockerd >/dev/null 2>&1 && return

# Start dockerd (use sudo when not root)
echo "[docker-autostart] Starting Docker daemon..."
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    sudo dockerd > /var/log/dockerd.log 2>&1 &
else
    dockerd > /var/log/dockerd.log 2>&1 &
fi

# Wait for Docker to actually respond (up to 30 seconds).
# Checking "docker info" is more reliable than just testing the socket file.
_docker_wait=30
while [ "$_docker_wait" -gt 0 ]; do
    if docker info >/dev/null 2>&1; then
        echo "[docker-autostart] Docker daemon is ready."
        unset _docker_wait
        return
    fi
    sleep 1
    _docker_wait=$((_docker_wait - 1))
done
unset _docker_wait

echo "[docker-autostart] WARNING: Docker daemon did not become ready within 30s." >&2
echo "[docker-autostart] Ensure the container is started with --privileged." >&2
echo "[docker-autostart] Check /var/log/dockerd.log for details." >&2
AUTOSTART_EOF

    sudo chmod +x "$autostart_path"

    # Also source from /etc/bash.bashrc so non-login interactive shells
    # (e.g. "docker run -it image bash") pick it up.
    if ! grep -q "docker-autostart.sh" /etc/bash.bashrc 2>/dev/null; then
        log_info "Adding Docker autostart hook to /etc/bash.bashrc..."
        printf '\n# Docker-in-Docker: auto-start dockerd for interactive sessions\n[ -f /etc/profile.d/docker-autostart.sh ] && . /etc/profile.d/docker-autostart.sh\n' \
            | sudo tee -a /etc/bash.bashrc > /dev/null
    fi

    log_success "Docker autostart installed at $autostart_path"
}

# Start dockerd as a background process (fallback when systemd is not available)
start_dockerd_background() {
    if pgrep -x dockerd >/dev/null 2>&1; then
        log_info "dockerd is already running"
        return 0
    fi

    log_info "Starting dockerd daemon in background..."
    sudo dockerd > /dev/null 2>&1 &
    local dockerd_pid=$!

    # Wait for Docker socket to become available (up to 15 seconds)
    local max_wait=15
    local waited=0
    while [ "$waited" -lt "$max_wait" ]; do
        if [ -S /var/run/docker.sock ]; then
            log_debug "Docker socket available after ${waited}s"
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done

    if pgrep -x dockerd >/dev/null 2>&1; then
        log_success "dockerd started in background (PID: $dockerd_pid)"
    else
        log_warn "dockerd may have failed to start"
    fi
}

# Ensure the Docker socket has correct group ownership and permissions
ensure_docker_socket_permissions() {
    local docker_sock="/var/run/docker.sock"
    if [ -S "$docker_sock" ]; then
        log_info "Ensuring Docker socket permissions..."
        # Set group ownership to docker
        sudo chown root:docker "$docker_sock" || log_warn "Failed to set docker socket group ownership"
        # Ensure group read/write access (srw-rw----)
        sudo chmod 660 "$docker_sock" || log_warn "Failed to set docker socket permissions"
        log_debug "Docker socket permissions: $(ls -la "$docker_sock")"
    else
        log_debug "Docker socket not found at $docker_sock (may appear after daemon starts)"
    fi
}

# Helper function to test Docker installation
test_docker_installation() {
    local env_type="${1:-native}"
    log_info "Testing Docker (environment: $env_type)..."

    # In container environments (Docker-in-Docker), the daemon is not running
    # during image build. Skip runtime tests — Docker will work via the
    # dockerd-entrypoint.sh at container start time.
    if [ "$env_type" = "container" ]; then
        log_info "Skipping Docker runtime test in container build context"
        log_info "Docker will be available at container runtime via dockerd-entrypoint.sh"
        return 0
    fi

    # Use sudo for initial test; group membership requires new login session
    if sudo docker run --rm hello-world >/dev/null 2>&1; then
        log_success "Docker test successful (via sudo)"
    else
        log_warn "Docker test with sudo failed"
        log_info "This may be normal during image building; Docker will work after reboot/re-login"
    fi

    # Check if non-root access works (may fail if group change requires re-login)
    if docker info >/dev/null 2>&1; then
        log_success "Docker accessible without sudo"
    else
        log_info "Docker requires re-login for non-root access (user added to docker group)"
        if [ "$env_type" = "native" ]; then
            log_info "Run 'newgrp docker' or log out and back in to use Docker without sudo"
        fi
    fi
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_docker
fi
