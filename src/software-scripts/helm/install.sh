#!/bin/bash

# Helm Installation Script
# This script installs the latest Helm (Kubernetes package manager)

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
SOFTWARE_NAME="helm"
SOFTWARE_DESCRIPTION="Helm (Kubernetes package manager)"
COMMAND_NAME="helm"
VERSION_FLAG="version --short --client"
GITHUB_REPO="helm/helm"

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
install_helm() {
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
            current_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -o 'v[0-9.]*' | head -1 || echo "unknown")
            log_info "$SOFTWARE_NAME is already installed (version: $current_version)"
            return 0
        fi
    fi
    
    # Helm installation script URL
    local install_script_url="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
    
    # Validate URL using security helpers if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$install_script_url" >/dev/null; then
            log_error "Invalid install script URL"
            return 1
        fi
    fi
    
    # Check prerequisites
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed"
        return 1
    fi
    
    # Create secure temporary directory for install script
    local temp_dir
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v create_secure_temp_dir >/dev/null 2>&1; then
        temp_dir=$(create_secure_temp_dir "helm")
    else
        temp_dir=$(mktemp -d)
        chmod 700 "$temp_dir"
    fi
    
    local install_script="$temp_dir/get_helm.sh"
    
    # Download the Helm install script using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v download_file >/dev/null 2>&1; then
        if ! download_file "$install_script_url" "$install_script"; then
            log_error "Failed to download Helm install script"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        # Fallback download
        log_info "Downloading Helm install script..."
        if ! curl -fsSL -o "$install_script" "$install_script_url"; then
            log_error "Failed to download Helm install script with curl"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # Verify the script downloaded successfully
    if [ ! -f "$install_script" ]; then
        log_error "Helm install script not found after download"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Make the script executable and run it
    chmod 700 "$install_script"
    
    log_info "Running Helm install script..."
    if (cd "$temp_dir" && ./get_helm.sh); then
        log_info "Helm install script completed"
    else
        log_error "Helm install script failed"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "$COMMAND_NAME version" "version"; then
            local installed_version
            installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            
            # Enable bash completion if available
            setup_helm_completion
            show_helm_usage_info
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local installed_version
            installed_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -o 'v[0-9.]*' | head -1 || echo "unknown")
            log_success "$SOFTWARE_NAME installed successfully (version: $installed_version)"
            
            # Enable bash completion if available
            setup_helm_completion
            show_helm_usage_info
            return 0
        else
            log_error "$SOFTWARE_NAME installation verification failed"
            return 1
        fi
    fi
}

# Helper function for Helm bash completion
setup_helm_completion() {
    if command -v helm >/dev/null 2>&1 && [ -d /etc/bash_completion.d ]; then
        log_info "Setting up Helm bash completion..."
        if helm completion bash | sudo tee /etc/bash_completion.d/helm > /dev/null 2>&1; then
            log_debug "Helm bash completion configured"
        else
            log_warn "Failed to configure Helm bash completion"
        fi
    fi
}

# Helper function to show usage information
show_helm_usage_info() {
    log_info "To get started with Helm:"
    log_info "  helm repo add stable https://charts.helm.sh/stable    # Add stable repo"
    log_info "  helm repo update                                     # Update repos"
    log_info "  helm search repo <chart-name>                       # Search for charts"
    log_info "  helm install <release-name> <chart>                 # Install a chart"
    log_info "  helm --help                                          # Show help"
    log_info ""
    log_info "Note: Helm requires kubectl to be configured with access to a Kubernetes cluster"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_helm
fi
