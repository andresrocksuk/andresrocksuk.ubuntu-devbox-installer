#!/bin/bash

# tflint installation script
# Terraform linter for finding errors and security issues

# Strict error handling
set -e

# Get script directory for relative sourcing
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../../utils"

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

# Tool information
TOOL_NAME="tflint"
TOOL_VERSION="v0.48.0"
TOOL_DESCRIPTION="Terraform linter for finding errors and security issues"

# Installation function
install_tflint() {
    log_info "Installing $TOOL_NAME $TOOL_VERSION..."
    
    # Check if already installed
    if command -v tflint >/dev/null 2>&1; then
        local current_version
        current_version=$(tflint --version | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        if [ "$current_version" = "$TOOL_VERSION" ] && [ "${FORCE_INSTALL:-false}" != "true" ]; then
            log_info "$TOOL_NAME $current_version already installed"
            return 0
        fi
    fi
    
    # Set up non-interactive environment
    setup_noninteractive_apt
    
    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Download tflint
    local download_url="https://github.com/terraform-linters/tflint/releases/download/${TOOL_VERSION}/tflint_linux_amd64.zip"
    local archive_file="$temp_dir/tflint.zip"
    
    log_info "Downloading $TOOL_NAME from: $download_url"
    
    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL "$download_url" -o "$archive_file"; then
            log_error "Failed to download $TOOL_NAME using curl"
            rm -rf "$temp_dir"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q "$download_url" -O "$archive_file"; then
            log_error "Failed to download $TOOL_NAME using wget"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        log_error "Neither curl nor wget available for downloading"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Verify download
    if [ ! -f "$archive_file" ] || [ ! -s "$archive_file" ]; then
        log_error "Downloaded file is missing or empty"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extract archive
    log_info "Extracting $TOOL_NAME..."
    if ! unzip -q "$archive_file" -d "$temp_dir"; then
        log_error "Failed to extract $TOOL_NAME archive"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Install binary
    local binary_path="$temp_dir/tflint"
    if [ ! -f "$binary_path" ]; then
        log_error "tflint binary not found in extracted archive"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Make binary executable
    chmod +x "$binary_path"
    
    # Move to system location
    log_info "Installing $TOOL_NAME to /usr/local/bin..."
    if ! sudo mv "$binary_path" "/usr/local/bin/tflint"; then
        log_error "Failed to install $TOOL_NAME to /usr/local/bin"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Clean up temporary directory
    rm -rf "$temp_dir"
    
    # Verify installation
    if command -v tflint >/dev/null 2>&1; then
        local installed_version
        installed_version=$(tflint --version | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "$TOOL_NAME $installed_version installed successfully"
        return 0
    else
        log_error "$TOOL_NAME installation verification failed"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting $TOOL_NAME installation..."
    
    if install_tflint; then
        log_success "$TOOL_NAME installation completed successfully"
        exit 0
    else
        log_error "$TOOL_NAME installation failed"
        exit 1
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
