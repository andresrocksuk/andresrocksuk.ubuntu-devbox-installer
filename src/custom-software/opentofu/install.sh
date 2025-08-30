#!/bin/bash

# OpenTofu Installation Script
# This script installs the latest OpenTofu (open-source Terraform alternative)

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
SOFTWARE_NAME="opentofu"
SOFTWARE_DESCRIPTION="OpenTofu (Open-source Terraform alternative)"
COMMAND_NAME="tofu"
VERSION_FLAG="version -json"
GITHUB_REPO="opentofu/opentofu"

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
install_opentofu() {
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
            current_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
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
    
    # Get latest release info from GitHub API
    local api_url="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
    
    # Validate URL using security helpers if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$api_url" >/dev/null; then
            log_error "Invalid API URL"
            return 1
        fi
    fi
    
    log_info "Fetching latest release information from GitHub..."
    
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
    local tag_name
    tag_name=$(echo "$release_info" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    local download_url
    download_url=$(echo "$release_info" | grep '"browser_download_url":' | grep "tofu_.*_linux_${arch}\.zip" | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$tag_name" ] || [ -z "$download_url" ]; then
        log_error "Could not parse release information from GitHub API"
        return 1
    fi
    
    log_info "Found OpenTofu version: $tag_name"
    log_debug "Download URL: $download_url"
    
    # Validate download URL if framework available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$download_url" >/dev/null; then
            log_error "Invalid download URL"
            return 1
        fi
    fi
    
    # Create secure temporary directory for downloads
    local temp_dir
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v create_secure_temp_dir >/dev/null 2>&1; then
        temp_dir=$(create_secure_temp_dir "opentofu")
    else
        temp_dir=$(mktemp -d)
        chmod 700 "$temp_dir"
    fi
    
    local temp_file="$temp_dir/opentofu.zip"
    
    # Download OpenTofu archive using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v download_file >/dev/null 2>&1; then
        if ! download_file "$download_url" "$temp_file"; then
            log_error "Failed to download OpenTofu archive"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        # Fallback download
        log_info "Downloading OpenTofu..."
        if command -v curl >/dev/null 2>&1; then
            if ! curl -fsSL -o "$temp_file" "$download_url"; then
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
    
    # Extract the archive
    log_info "Extracting OpenTofu..."
    cd "$temp_dir"
    if ! unzip -q "$temp_file"; then
        log_error "Failed to extract OpenTofu archive"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Install the binary
    if [ ! -f "$temp_dir/tofu" ]; then
        log_error "OpenTofu binary not found in extracted archive"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_info "Installing OpenTofu..."
    sudo mv "$temp_dir/tofu" "/usr/local/bin/$COMMAND_NAME"
    sudo chmod +x "/usr/local/bin/$COMMAND_NAME"
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "$COMMAND_NAME --help" "OpenTofu"; then
            local installed_version
            installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            show_opentofu_usage_info
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local installed_version
            installed_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
            log_success "$SOFTWARE_NAME installed successfully (version: $installed_version)"
            
            # Test installation
            log_info "Testing $SOFTWARE_NAME installation..."
            if $COMMAND_NAME --help >/dev/null 2>&1; then
                log_success "$SOFTWARE_NAME test successful"
            else
                log_warn "$SOFTWARE_NAME test failed, but installation appears successful"
            fi
            
            show_opentofu_usage_info
            return 0
        else
            log_error "$SOFTWARE_NAME installation verification failed"
            return 1
        fi
    fi
}

# Helper function to show usage information
show_opentofu_usage_info() {
    log_info "To get started with OpenTofu:"
    log_info "  tofu init              # Initialize a working directory"
    log_info "  tofu plan              # Create an execution plan"
    log_info "  tofu apply             # Execute the plan"
    log_info "  tofu --help            # Show help"
    log_info ""
    log_info "Documentation: https://opentofu.org/docs/"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_opentofu
fi

