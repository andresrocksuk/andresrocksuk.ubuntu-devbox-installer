#!/bin/bash

# PowerShell Core Installation Script
# This script installs the latest PowerShell Core

set -e

# Determine script directory
POWERSHELL_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$(dirname "$POWERSHELL_SCRIPT_DIR")")/utils"

# Source the installation framework
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
else
    echo "[ERROR] Installation framework not found at $UTILS_DIR/installation-framework.sh"
    exit 1
fi

# Source package manager for apt functions
if [ -f "$UTILS_DIR/package-manager.sh" ]; then
    source "$UTILS_DIR/package-manager.sh"
else
    echo "[ERROR] Package manager not found at $UTILS_DIR/package-manager.sh"
    exit 1
fi

# Standalone execution support
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    log_info "Running PowerShell installation script in standalone mode"
fi

install_powershell_core() {
    log_info "Installing PowerShell Core..."

    # Check if already installed and get version
    if command -v pwsh >/dev/null 2>&1; then
        local current_version
        current_version=$(pwsh -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || echo "unknown")
        log_info "PowerShell is already installed (version: $current_version)"
        
        # Get latest version from GitHub API
        log_info "Checking for latest PowerShell version..."
        local latest_version
        latest_version=$(curl -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4 | cut -d'v' -f2 2>/dev/null || echo "unknown")
        
        if [ "$current_version" = "$latest_version" ] && [ "$current_version" != "unknown" ]; then
            log_success "PowerShell is already up to date (version: $current_version)"
            show_powershell_usage_info "$current_version"
            return 0
        else
            log_info "Newer version available: $latest_version (current: $current_version)"
            log_info "Proceeding with update..."
        fi
    fi

    # Install prerequisites
    log_info "Installing prerequisites..."
    update_package_lists
    if ! install_apt_package wget latest; then
        log_error "Failed to install wget"
        return 1
    fi
    if ! install_apt_package apt-transport-https latest; then
        log_error "Failed to install apt-transport-https"
        return 1
    fi
    if ! install_apt_package software-properties-common latest; then
        log_error "Failed to install software-properties-common"
        return 1
    fi

    # Get Ubuntu version
    local ubuntu_version
    ubuntu_version=$(lsb_release -rs)
    log_info "Detected Ubuntu version: $ubuntu_version"

    # Download Microsoft package signing key and add repository
    log_info "Adding Microsoft repository..."
    
    # Use temporary directory for downloads
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Clean up temp directory on exit
    trap "rm -rf '$temp_dir'" EXIT
    
    cd "$temp_dir"
    if ! wget -q "https://packages.microsoft.com/config/ubuntu/$ubuntu_version/packages-microsoft-prod.deb"; then
        log_error "Failed to download Microsoft repository package"
        return 1
    fi

    # Setup non-interactive environment before dpkg operations
    setup_noninteractive_apt
    
    if ! sudo dpkg -i packages-microsoft-prod.deb; then
        log_error "Failed to install Microsoft repository package"
        return 1
    fi

    # Update package list with new repository
    log_info "Updating package lists..."
    update_package_lists

    # Install PowerShell
    log_info "Installing PowerShell..."
    if ! install_apt_package powershell latest; then
        log_error "Failed to install PowerShell"
        return 1
    fi

    # Verify installation
    if command -v pwsh >/dev/null 2>&1; then
        local version
        version=$(pwsh -c '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || echo "unknown")
        log_success "PowerShell installed successfully (version: $version)"
        
        # Set up PowerShell profile directory
        log_info "Setting up PowerShell profile directory..."
        if ! pwsh -c 'if (!(Test-Path $PROFILE)) { New-Item -Path $PROFILE -Type File -Force | Out-Null }' 2>/dev/null; then
            log_warn "Could not create PowerShell profile directory"
        fi
        
        # Show usage information
        show_powershell_usage_info "$version"
        return 0
    else
        log_error "PowerShell installation verification failed"
        return 1
    fi
}

show_powershell_usage_info() {
    local version="$1"
    
    log_info ""
    log_info "PowerShell installation completed successfully (version: $version)"
    log_info ""
    log_info "To get started with PowerShell:"
    log_info "  pwsh                        # Start PowerShell"
    log_info "  pwsh -c 'Get-Help'          # Show help system"
    log_info "  pwsh -c 'Get-Command'       # List available commands"
    log_info "  pwsh -c 'Update-Help'       # Update help system"
    log_info ""
    
    local profile_path
    profile_path=$(pwsh -c 'echo $PROFILE' 2>/dev/null || echo "unknown")
    if [ "$profile_path" != "unknown" ]; then
        log_info "PowerShell profile location:"
        log_info "  $profile_path"
        log_info ""
    fi
    
    log_info "Documentation: https://docs.microsoft.com/powershell/"
}

# Main execution
main() {
    install_powershell_core
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
