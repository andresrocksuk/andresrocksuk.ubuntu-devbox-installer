#!/bin/bash

# installation-framework.sh - Common installation framework for software scripts
# This module provides standardized functions for software installation scripts

# Handle being sourced from different directories
if [ -n "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
    if [ "$SCRIPT_DIR" = "${BASH_SOURCE[0]}" ]; then
        SCRIPT_DIR="."
    fi
    SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
else
    SCRIPT_DIR="${0%/*}"
    if [ "$SCRIPT_DIR" = "$0" ]; then
        SCRIPT_DIR="."
    fi
    SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
fi

# Source required utilities
source "$SCRIPT_DIR/logger.sh"
source "$SCRIPT_DIR/version-checker.sh"
source "$SCRIPT_DIR/package-manager.sh"

# Global variables for installation framework
declare -A INSTALL_FRAMEWORK_CONFIG=(
    [temp_dir]="/tmp"
    [max_retries]="3"
    [retry_delay]="2"
    [timeout]="300"
)

# Function to initialize a software installation script
# Usage: initialize_script "script_name" "software_description"
initialize_script() {
    local script_name="$1"
    local software_description="${2:-$script_name}"
    
    # Validate inputs
    if [[ ! "$script_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid script name: $script_name. Only alphanumeric characters, hyphens, and underscores allowed."
        return 1
    fi
    
    # Export script information for use by other functions
    export INSTALL_SCRIPT_NAME="$script_name"
    export INSTALL_SOFTWARE_DESCRIPTION="$software_description"
    
    # Set up script directory paths
    export INSTALL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    export INSTALL_UTILS_DIR="$(cd "$INSTALL_SCRIPT_DIR/../../utils" && pwd)"
    export INSTALL_ROOT_DIR="$(cd "$INSTALL_SCRIPT_DIR/../.." && pwd)"
    
    # Source additional utilities if available
    if [ -f "$INSTALL_UTILS_DIR/shell-config.sh" ]; then
        source "$INSTALL_UTILS_DIR/shell-config.sh"
    fi
    
    # Set up logging context
    log_debug "Initialized installation script: $script_name"
    log_debug "Script directory: $INSTALL_SCRIPT_DIR"
    log_debug "Utils directory: $INSTALL_UTILS_DIR"
    
    return 0
}

# Function to check if software is already installed
# Usage: check_already_installed "command_name" ["version_flag"]
check_already_installed() {
    local command_name="$1"
    local version_flag="${2:---version}"
    
    # Validate command name
    if [[ ! "$command_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid command name: $command_name"
        return 2
    fi
    
    if command_exists "$command_name"; then
        local current_version
        current_version=$(get_command_version "$command_name" "$version_flag" 2>/dev/null || echo "unknown")
        
        log_info "$command_name is already installed (version: $current_version)"
        return 0  # Already installed
    else
        log_debug "$command_name is not installed"
        return 1  # Not installed
    fi
}

# Function to download a file securely
# Usage: download_file "url" "destination_path" ["expected_checksum"]
download_file() {
    local url="$1"
    local destination="$2"
    local expected_checksum="$3"
    
    # Validate URL format
    if ! validate_url "$url"; then
        log_error "Invalid URL format: $url"
        return 1
    fi
    
    # Validate destination path
    if [[ ! "$destination" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
        log_error "Invalid destination path: $destination"
        return 1
    fi
    
    # Create destination directory if needed
    local dest_dir="$(dirname "$destination")"
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir" || {
            log_error "Failed to create directory: $dest_dir"
            return 1
        }
    fi
    
    log_info "Downloading from: $url"
    log_debug "Destination: $destination"
    
    # Try download with curl first, then wget
    local download_success=false
    local attempt=1
    
    while [ $attempt -le "${INSTALL_FRAMEWORK_CONFIG[max_retries]}" ]; do
        log_debug "Download attempt $attempt/${INSTALL_FRAMEWORK_CONFIG[max_retries]}"
        
        if command_exists "curl"; then
            if curl -fsSL --connect-timeout 30 --max-time "${INSTALL_FRAMEWORK_CONFIG[timeout]}" "$url" -o "$destination"; then
                download_success=true
                break
            fi
        elif command_exists "wget"; then
            if wget --timeout="${INSTALL_FRAMEWORK_CONFIG[timeout]}" --tries=1 -O "$destination" "$url"; then
                download_success=true
                break
            fi
        else
            log_error "Neither curl nor wget is available for downloading"
            return 1
        fi
        
        log_warn "Download attempt $attempt failed, retrying in ${INSTALL_FRAMEWORK_CONFIG[retry_delay]} seconds..."
        sleep "${INSTALL_FRAMEWORK_CONFIG[retry_delay]}"
        ((attempt++))
    done
    
    if [ "$download_success" = false ]; then
        log_error "Failed to download after ${INSTALL_FRAMEWORK_CONFIG[max_retries]} attempts"
        return 1
    fi
    
    # Verify file was downloaded
    if [ ! -f "$destination" ]; then
        log_error "Downloaded file not found: $destination"
        return 1
    fi
    
    # Verify checksum if provided
    if [ -n "$expected_checksum" ]; then
        if command_exists "sha256sum"; then
            local actual_checksum
            actual_checksum=$(sha256sum "$destination" | cut -d' ' -f1)
            if [ "$actual_checksum" != "$expected_checksum" ]; then
                log_error "Checksum verification failed"
                log_error "Expected: $expected_checksum"
                log_error "Actual: $actual_checksum"
                rm -f "$destination"
                return 1
            fi
            log_success "Checksum verification passed"
        else
            log_warn "sha256sum not available, skipping checksum verification"
        fi
    fi
    
    log_success "Download completed successfully"
    return 0
}

# Function to verify installation success
# Usage: verify_installation "command_name" ["test_command"] ["expected_output_pattern"]
verify_installation() {
    local command_name="$1"
    local test_command="${2:-$command_name --help}"
    local expected_pattern="$3"
    
    # Validate command name
    if [[ ! "$command_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid command name: $command_name"
        return 1
    fi
    
    log_info "Verifying $command_name installation..."
    
    # Check if command exists
    if ! command_exists "$command_name"; then
        log_error "$command_name installation verification failed: command not found"
        return 1
    fi
    
    # Get and log version information
    local version
    version=$(get_command_version "$command_name" 2>/dev/null || echo "unknown")
    log_success "$command_name installed successfully (version: $version)"
    
    # Run test command if provided
    if [ -n "$test_command" ]; then
        log_info "Testing $command_name with: $test_command"
        
        # Use timeout to prevent hanging
        if timeout 30 $test_command >/dev/null 2>&1; then
            log_success "$command_name test successful"
        else
            log_warn "$command_name test failed, but installation appears successful"
        fi
    fi
    
    # Check for expected output pattern if provided
    if [ -n "$expected_pattern" ] && [ -n "$test_command" ]; then
        log_debug "Checking for expected pattern: $expected_pattern"
        local output
        output=$(timeout 30 $test_command 2>&1 || true)
        
        if echo "$output" | grep -q "$expected_pattern"; then
            log_success "Expected output pattern found"
        else
            log_warn "Expected output pattern not found, but installation appears successful"
        fi
    fi
    
    return 0
}

# Function to log installation results consistently
# Usage: log_installation_result "software_name" "status" ["version"] ["additional_info"]
log_installation_result() {
    local software_name="$1"
    local status="$2"  # "success", "failure", "skipped", "already_installed"
    local version="$3"
    local additional_info="$4"
    
    # Validate inputs
    if [[ ! "$software_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid software name: $software_name"
        return 1
    fi
    
    if [[ ! "$status" =~ ^(success|failure|skipped|already_installed)$ ]]; then
        log_error "Invalid status: $status. Must be one of: success, failure, skipped, already_installed"
        return 1
    fi
    
    local version_info=""
    if [ -n "$version" ]; then
        version_info=" (version: $version)"
    fi
    
    local additional_text=""
    if [ -n "$additional_info" ]; then
        additional_text=" - $additional_info"
    fi
    
    case "$status" in
        "success")
            log_success "$software_name installation completed successfully$version_info$additional_text"
            ;;
        "failure")
            log_error "$software_name installation failed$additional_text"
            ;;
        "skipped")
            log_info "$software_name installation skipped$additional_text"
            ;;
        "already_installed")
            log_info "$software_name is already installed$version_info$additional_text"
            ;;
    esac
    
    return 0
}

# Function to validate URL format
# Usage: validate_url "url"
validate_url() {
    local url="$1"
    
    # Clean URL first by removing any carriage returns, newlines, or trailing whitespace
    url=$(echo "$url" | tr -d '\r\n' | xargs)
    
    # Basic URL validation - must start with http:// or https://
    if [[ "$url" =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate version format
# Usage: validate_version_format "version"
validate_version_format() {
    local version="$1"
    
    # Allow semantic versioning, build numbers, and simple version strings
    if [[ "$version" =~ ^[a-zA-Z0-9v._-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate system architecture
# Usage: validate_architecture "arch"
validate_architecture() {
    local arch="$1"
    
    # Common architectures
    case "$arch" in
        "amd64"|"x86_64"|"arm64"|"aarch64"|"armv6l"|"armv7l"|"i386"|"i686")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to sanitize input strings
# Usage: sanitize_input "input_string"
sanitize_input() {
    local input="$1"
    
    # Remove potentially dangerous characters, keep only alphanumeric, dots, hyphens, underscores, slashes
    echo "$input" | tr -cd 'a-zA-Z0-9._/-'
}

# Function to create secure temporary file
# Usage: create_temp_file ["prefix"] ["suffix"]
create_temp_file() {
    local prefix="${1:-install}"
    local suffix="$2"
    
    # Validate prefix
    if [[ ! "$prefix" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid temp file prefix: $prefix"
        return 1
    fi
    
    local temp_file
    if [ -n "$suffix" ]; then
        temp_file=$(mktemp "${INSTALL_FRAMEWORK_CONFIG[temp_dir]}/${prefix}.XXXXXX${suffix}")
    else
        temp_file=$(mktemp "${INSTALL_FRAMEWORK_CONFIG[temp_dir]}/${prefix}.XXXXXX")
    fi
    
    if [ -z "$temp_file" ] || [ ! -f "$temp_file" ]; then
        log_error "Failed to create temporary file"
        return 1
    fi
    
    # Set restrictive permissions
    chmod 600 "$temp_file"
    
    echo "$temp_file"
    return 0
}

# Function to get system architecture in standard format
# Usage: get_system_architecture
get_system_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        "x86_64")
            echo "amd64"
            ;;
        "aarch64")
            echo "arm64"
            ;;
        "armv6l"|"armv7l")
            echo "armv6l"
            ;;
        *)
            echo "$arch"
            ;;
    esac
}

# Function to setup fallback logging functions for standalone scripts
# Usage: setup_fallback_logging
setup_fallback_logging() {
    if ! command_exists "log_info"; then
        log_info() { echo "[INFO] $1"; }
        log_warn() { echo "[WARN] $1"; }
        log_error() { echo "[ERROR] $1" >&2; }
        log_debug() { 
            if [ "${LOG_LEVEL:-INFO}" = "DEBUG" ]; then
                echo "[DEBUG] $1" >&2
            fi
        }
        log_success() { echo "[SUCCESS] $1"; }
        log_section() { 
            echo ""
            echo "==== $1 ===="
        }
    fi
}

# Function to handle standalone execution mode
# Usage: handle_standalone_execution "script_name"
handle_standalone_execution() {
    local script_name="$1"
    
    if [ "${BASH_SOURCE[1]}" = "${1:-${0}}" ]; then
        log_info "Running $script_name installation script in standalone mode"
        setup_fallback_logging
        return 0  # Is standalone
    else
        return 1  # Not standalone
    fi
}
