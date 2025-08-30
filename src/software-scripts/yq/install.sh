#!/bin/bash

# yq installation script
# Installs yq (YAML processor) from GitHub releases

set -e

# Source the installation framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$(cd "$SCRIPT_DIR/../../utils" && pwd)"

# Source utilities and framework
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
    source "$UTILS_DIR/security-helpers.sh"
    FRAMEWORK_AVAILABLE=true
else
    FRAMEWORK_AVAILABLE=false
    # Fallback: source individual utilities
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
SOFTWARE_NAME="yq"
SOFTWARE_DESCRIPTION="yq (YAML processor)"
COMMAND_NAME="yq"
VERSION_FLAG="--version"
GITHUB_REPO="mikefarah/yq"

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
install_yq() {
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
            current_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")
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
    download_url=$(echo "$release_info" | grep '"browser_download_url":.*yq_linux_'$arch'"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$tag_name" ] || [ -z "$download_url" ]; then
        log_error "Could not parse release information from GitHub API"
        return 1
    fi
    
    log_info "Found yq version: $tag_name"
    log_debug "Download URL: $download_url"
    
    # Validate download URL if framework available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$download_url" >/dev/null; then
            log_error "Invalid download URL"
            return 1
        fi
    fi
    
    # Download yq binary using framework if available
    local temp_file
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v create_temp_file >/dev/null 2>&1; then
        temp_file=$(create_temp_file "yq")
    else
        temp_file="/tmp/yq.$$"
    fi
    
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v download_file >/dev/null 2>&1; then
        if ! download_file "$download_url" "$temp_file"; then
            log_error "Failed to download yq binary"
            return 1
        fi
    else
        # Fallback download
        log_info "Downloading yq binary..."
        if command -v curl >/dev/null 2>&1; then
            if ! curl -fsSL -o "$temp_file" "$download_url"; then
                log_error "Download failed with curl"
                return 1
            fi
        elif command -v wget >/dev/null 2>&1; then
            if ! wget -O "$temp_file" "$download_url"; then
                log_error "Download failed with wget"
                return 1
            fi
        fi
    fi
    
    # Make executable and install
    chmod +x "$temp_file"
    sudo mv "$temp_file" "/usr/local/bin/$COMMAND_NAME"
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "echo 'test: value' | $COMMAND_NAME eval '.test' -" "value"; then
            local installed_version
            installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local installed_version
            installed_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")
            log_success "$SOFTWARE_NAME installed successfully (version: $installed_version)"
            
            # Test installation
            log_info "Testing $SOFTWARE_NAME installation..."
            if echo "test: value" | $COMMAND_NAME eval '.test' - >/dev/null 2>&1; then
                log_success "$SOFTWARE_NAME test successful"
            else
                log_warn "$SOFTWARE_NAME test failed, but installation appears successful"
            fi
            
            return 0
        else
            log_error "$SOFTWARE_NAME installation verification failed"
            return 1
        fi
    fi
}

# Run installation
install_yq
