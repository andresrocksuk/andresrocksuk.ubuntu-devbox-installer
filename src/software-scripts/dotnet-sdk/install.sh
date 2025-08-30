#!/bin/bash

# .NET SDK Installation Script
# This script installs the latest .NET SDK 8

set -e

# Define software metadata
SOFTWARE_NAME="dotnet-sdk"
SOFTWARE_DESCRIPTION=".NET SDK 8.0"
COMMAND_NAME="dotnet"
VERSION_FLAG="--version"
GITHUB_REPO=""  # Not used for Microsoft package repository

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
fi

install_dotnet_sdk() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if already installed (using framework if available)
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_already_installed >/dev/null 2>&1; then
        if check_already_installed "$COMMAND_NAME" "$VERSION_FLAG"; then
            # Check if it's .NET 8.x
            local current_version=$(dotnet --version 2>/dev/null || echo "unknown")
            if [[ "$current_version" == 8.* ]]; then
                log_success ".NET SDK 8.x is already installed and up to date"
                return 0
            else
                log_info "Current version is $current_version, installing .NET 8.x..."
            fi
        fi
    else
        # Fallback: manual check
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local current_version=$(dotnet --version 2>/dev/null || echo "unknown")
            log_info "$SOFTWARE_DESCRIPTION is already installed (version: $current_version)"
            
            # Check if it's .NET 8.x
            if [[ "$current_version" == 8.* ]]; then
                log_success ".NET SDK 8.x is already installed and up to date"
                return 0
            else
                log_info "Current version is $current_version, installing .NET 8.x..."
            fi
        fi
    fi
    
    # Check if running on supported OS
    if ! grep -q "Ubuntu\|Debian" /etc/os-release; then
        log_error "This script is designed for Ubuntu/Debian systems"
        return 1
    fi
    
    # Install prerequisites
    log_info "Installing prerequisites..."
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y wget apt-transport-https software-properties-common >/dev/null 2>&1
    
    # Get Ubuntu version
    local ubuntu_version=$(lsb_release -rs)
    log_info "Detected Ubuntu version: $ubuntu_version"
    
    # Download Microsoft package signing key
    log_info "Adding Microsoft package signing key..."
    
    local packages_url="https://packages.microsoft.com/config/ubuntu/$ubuntu_version/packages-microsoft-prod.deb"
    
    # Validate URL using security helpers if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$packages_url" >/dev/null; then
            log_error "Invalid packages URL"
            return 1
        fi
    fi
    
    # Create secure temporary directory
    local temp_dir
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v create_secure_temp_dir >/dev/null 2>&1; then
        temp_dir=$(create_secure_temp_dir "dotnet")
    else
        temp_dir=$(mktemp -d)
        chmod 700 "$temp_dir"
    fi
    
    local packages_file="$temp_dir/packages-microsoft-prod.deb"
    
    # Download Microsoft packages configuration using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v download_file >/dev/null 2>&1; then
        if ! download_file "$packages_url" "$packages_file"; then
            log_error "Failed to download Microsoft packages configuration"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        # Fallback download
        if ! wget "$packages_url" -O "$packages_file"; then
            log_error "Failed to download Microsoft packages configuration"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # Install Microsoft packages configuration
    sudo dpkg -i "$packages_file"
    rm -rf "$temp_dir"
    
    # Update package list
    log_info "Updating package lists..."
    sudo apt-get update >/dev/null 2>&1
    
    # Install .NET SDK 8
    log_info "Installing .NET SDK 8..."
    sudo apt-get install -y dotnet-sdk-8.0 >/dev/null 2>&1
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "$COMMAND_NAME --version" ".NET SDK"; then
            local installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            show_dotnet_info
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local version=$(dotnet --version 2>/dev/null || echo "unknown")
            log_success "$SOFTWARE_DESCRIPTION installed successfully (version: $version)"
            show_dotnet_info
            return 0
        else
            log_error "$SOFTWARE_DESCRIPTION installation failed"
            return 1
        fi
    fi
}

# Helper function to show .NET information
show_dotnet_info() {
    # Show installed SDKs and runtimes
    log_info "Installed .NET SDKs:"
    dotnet --list-sdks 2>/dev/null | sed 's/^/  /' || log_warn "Could not list SDKs"
    
    log_info "Installed .NET Runtimes:"
    dotnet --list-runtimes 2>/dev/null | sed 's/^/  /' || log_warn "Could not list runtimes"
    
    # Show basic usage info
    log_info ""
    log_info "To get started with .NET:"
    log_info "  dotnet new console -n MyApp    # Create a new console application"
    log_info "  dotnet run                      # Run the application"
    log_info "  dotnet build                    # Build the application"
    log_info "  dotnet test                     # Run tests"
    log_info "  dotnet --help                   # Show help"
    log_info ""
    log_info "Documentation: https://docs.microsoft.com/dotnet/"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_dotnet_sdk
fi
