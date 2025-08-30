#!/bin/bash

# kubectl Installation Script
# This script installs the latest stable kubectl

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
SOFTWARE_NAME="kubectl"
SOFTWARE_DESCRIPTION="kubectl (Kubernetes command-line tool)"
COMMAND_NAME="kubectl"
VERSION_FLAG="version --client --output=yaml"
KUBECTL_STABLE_URL="https://dl.k8s.io/release/stable.txt"

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

# Main installation function
install_kubectl() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if already installed (using framework if available)
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_already_installed >/dev/null 2>&1; then
        if check_already_installed "$COMMAND_NAME" "$VERSION_FLAG"; then
            # Framework function already logged the result, no need for additional logging
            return 0
        fi
    else
        # Fallback: manual check
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local current_version
            current_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -o 'gitVersion: v[0-9.]*' | cut -d'v' -f2 || echo "unknown")
            log_info "$SOFTWARE_NAME is already installed (version: $current_version)"
            return 0
        fi
    fi
    
    # Get system architecture using framework if available
    local arch
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v get_system_architecture >/dev/null 2>&1; then
        arch=$(get_system_architecture)
    else
        # Fallback architecture detection
        arch=$(uname -m)
        case $arch in
            x86_64) arch="amd64" ;;
            aarch64) arch="arm64" ;;
            armv6l|armv7l) arch="arm" ;;
            *) 
                log_error "Unsupported architecture: $arch"
                return 1
                ;;
        esac
    fi
    
    # Validate stable URL using security helpers if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$KUBECTL_STABLE_URL" >/dev/null; then
            log_error "Invalid stable version URL"
            return 1
        fi
    fi
    
    # Get latest stable version
    log_info "Fetching latest kubectl version..."
    local latest_version
    if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -L -s "$KUBECTL_STABLE_URL")
    elif command -v wget >/dev/null 2>&1; then
        latest_version=$(wget -qO- "$KUBECTL_STABLE_URL")
    else
        log_error "Neither curl nor wget available for downloading"
        return 1
    fi
    
    if [ -z "$latest_version" ]; then
        log_error "Failed to fetch latest kubectl version"
        return 1
    fi
    
    log_info "Latest kubectl version: $latest_version"
    
    # Construct download URLs
    local download_url="https://dl.k8s.io/release/$latest_version/bin/linux/$arch/kubectl"
    local checksum_url="https://dl.k8s.io/release/$latest_version/bin/linux/$arch/kubectl.sha256"
    
    # Validate download URLs if framework available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$download_url" >/dev/null; then
            log_error "Invalid download URL"
            return 1
        fi
        if ! validate_and_sanitize_url "$checksum_url" >/dev/null; then
            log_error "Invalid checksum URL"
            return 1
        fi
    fi
    
    # Create secure temporary directory for downloads
    local temp_dir
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v create_secure_temp_dir >/dev/null 2>&1; then
        temp_dir=$(create_secure_temp_dir "kubectl")
    else
        temp_dir=$(mktemp -d)
        chmod 700 "$temp_dir"
    fi
    
    local kubectl_binary="$temp_dir/kubectl"
    local checksum_file="$temp_dir/kubectl.sha256"
    
    # Download kubectl binary using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v download_file >/dev/null 2>&1; then
        if ! download_file "$download_url" "$kubectl_binary"; then
            log_error "Failed to download kubectl binary"
            rm -rf "$temp_dir"
            return 1
        fi
        if ! download_file "$checksum_url" "$checksum_file"; then
            log_error "Failed to download kubectl checksum"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        # Fallback download
        log_info "Downloading kubectl binary..."
        if command -v curl >/dev/null 2>&1; then
            if ! curl -fsSL -o "$kubectl_binary" "$download_url"; then
                log_error "Download failed with curl"
                rm -rf "$temp_dir"
                return 1
            fi
            if ! curl -fsSL -o "$checksum_file" "$checksum_url"; then
                log_error "Checksum download failed with curl"
                rm -rf "$temp_dir"
                return 1
            fi
        elif command -v wget >/dev/null 2>&1; then
            if ! wget -O "$kubectl_binary" "$download_url"; then
                log_error "Download failed with wget"
                rm -rf "$temp_dir"
                return 1
            fi
            if ! wget -O "$checksum_file" "$checksum_url"; then
                log_error "Checksum download failed with wget"
                rm -rf "$temp_dir"
                return 1
            fi
        fi
    fi
    
    # Verify the binary checksum
    log_info "Verifying kubectl binary..."
    if command -v sha256sum >/dev/null 2>&1; then
        cd "$temp_dir"
        if ! echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check; then
            log_error "kubectl binary verification failed"
            rm -rf "$temp_dir"
            return 1
        fi
        cd /
    else
        log_warn "sha256sum not available, skipping checksum verification"
    fi
    
    # Install kubectl
    log_info "Installing kubectl to /usr/local/bin/..."
    sudo install -o root -g root -m 0755 "$kubectl_binary" /usr/local/bin/kubectl
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "$COMMAND_NAME version --client" "gitVersion"; then
            local installed_version
            installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            
            # Enable bash completion if available
            setup_kubectl_completion
            show_kubectl_usage_info
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local installed_version
            installed_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -o 'gitVersion: v[0-9.]*' | cut -d'v' -f2 || echo "unknown")
            log_success "$SOFTWARE_NAME installed successfully (version: $installed_version)"
            
            # Enable bash completion if available
            setup_kubectl_completion
            show_kubectl_usage_info
            return 0
        else
            log_error "$SOFTWARE_NAME installation verification failed"
            return 1
        fi
    fi
}

# Helper function for kubectl bash completion
setup_kubectl_completion() {
    if command -v kubectl >/dev/null 2>&1 && [ -d /etc/bash_completion.d ]; then
        log_info "Setting up kubectl bash completion..."
        if kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null 2>&1; then
            log_debug "kubectl bash completion configured"
        else
            log_warn "Failed to configure kubectl bash completion"
        fi
    fi
}

# Helper function to show usage information
show_kubectl_usage_info() {
    log_info "To get started with kubectl:"
    log_info "  kubectl cluster-info        # Display cluster info"
    log_info "  kubectl get nodes           # List cluster nodes"
    log_info "  kubectl --help              # Show help"
    log_info ""
    log_info "Note: You'll need to configure kubectl with a kubeconfig file to connect to a cluster"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_kubectl
fi
