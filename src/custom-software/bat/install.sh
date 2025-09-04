#!/bin/bash

# bat installation script
# Installs bat (better cat) via apt

set -e

# Define software metadata
SOFTWARE_NAME="bat"
SOFTWARE_DESCRIPTION="bat (better cat with syntax highlighting)"
COMMAND_NAME="bat"
VERSION_FLAG="--version"
GITHUB_REPO=""  # Not used for APT installation

# Get script directory and source framework
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/../utils"

# Try to source the installation framework
FRAMEWORK_AVAILABLE="false"
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
    FRAMEWORK_AVAILABLE="true"
fi

# Source package manager utilities
if [ -f "$UTILS_DIR/package-manager.sh" ]; then
    source "$UTILS_DIR/package-manager.sh"
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

install_bat() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if already installed (using framework if available)
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_already_installed >/dev/null 2>&1; then
        # First check for standard bat command
        if check_already_installed "$COMMAND_NAME" "$VERSION_FLAG"; then
            return 0
        fi
        # Also check for batcat (Ubuntu package name)
        if check_already_installed "batcat" "$VERSION_FLAG"; then
            setup_bat_alias
            return 0
        fi
    else
        # Fallback: manual check
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local current_version=$(bat --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_info "$SOFTWARE_DESCRIPTION is already installed (version: $current_version)"
            return 0
        fi
        
        # Check if batcat is installed (Ubuntu package name)
        if command -v batcat >/dev/null 2>&1; then
            local current_version=$(batcat --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_info "$SOFTWARE_DESCRIPTION is already installed as batcat (version: $current_version)"
            setup_bat_alias
            return 0
        fi
    fi
    
    # Setup non-interactive environment for package installation
    setup_noninteractive_apt
    
    # Update package list
    log_info "Updating package list..."
    safe_apt_update
    
    # Install bat
    log_info "Installing bat via apt..."
    safe_apt_install bat
    
    # Setup bat alias if needed
    setup_bat_alias
    
    # Verify installation using framework if available
    local bat_cmd="$COMMAND_NAME"
    if ! command -v "$COMMAND_NAME" >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
        bat_cmd="batcat"
    fi
    
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$bat_cmd" "$bat_cmd --help" "bat"; then
            local installed_version=$(get_command_version "$bat_cmd" "$VERSION_FLAG" 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            show_bat_usage_info
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$bat_cmd" >/dev/null 2>&1; then
            local installed_version=$($bat_cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_success "$SOFTWARE_DESCRIPTION installed successfully (version: $installed_version)"
            
            # Test run
            log_info "Testing bat..."
            $bat_cmd --help >/dev/null 2>&1 && log_success "bat test successful"
            
            show_bat_usage_info
            return 0
        else
            log_error "$SOFTWARE_DESCRIPTION installation verification failed"
            return 1
        fi
    fi
}

# Helper function to set up bat alias
setup_bat_alias() {
    # Create bat alias if only batcat is available
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
        log_info "Creating bat alias for batcat..."
        sudo ln -sf $(which batcat) /usr/local/bin/bat
    fi
}

# Helper function to show usage information
show_bat_usage_info() {
    log_info "To use bat:"
    log_info "  bat <file>                 # Display file with syntax highlighting"
    log_info "  bat --list-languages       # Show supported languages"
    log_info "  bat --style=numbers        # Show with line numbers"
    log_info "  bat --help                 # Show help"
    log_info ""
    log_info "bat is a cat replacement with syntax highlighting and Git integration"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_bat
fi
