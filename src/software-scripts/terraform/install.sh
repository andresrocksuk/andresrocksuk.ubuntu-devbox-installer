#!/bin/bash

# Terraform Installation Script
# This script installs the latest Terraform from HashiCorp repository

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
SOFTWARE_NAME="terraform"
SOFTWARE_DESCRIPTION="Terraform (Infrastructure as Code)"
COMMAND_NAME="terraform"
VERSION_FLAG="version -json"
HASHICORP_GPG_URL="https://apt.releases.hashicorp.com/gpg"
HASHICORP_REPO_BASE="https://apt.releases.hashicorp.com"

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
install_terraform() {
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
            current_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
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
    
    # Check prerequisites
    local missing_tools=()
    if ! command -v curl >/dev/null 2>&1; then
        missing_tools+=("curl")
    fi
    if ! command -v unzip >/dev/null 2>&1; then
        missing_tools+=("unzip")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    # Get latest version from HashiCorp API
    local api_url="https://api.releases.hashicorp.com/v1/releases/terraform"
    
    # Validate URL using security helpers if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v validate_and_sanitize_url >/dev/null 2>&1; then
        if ! validate_and_sanitize_url "$api_url" >/dev/null; then
            log_error "Invalid API URL"
            return 1
        fi
    fi
    
    log_info "Fetching latest Terraform version..."
    local latest_version
    latest_version=$(curl -s "$api_url" | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$latest_version" ]; then
        log_error "Failed to fetch latest Terraform version"
        return 1
    fi
    
    log_info "Latest Terraform version: $latest_version"
    
    # Construct download URLs
    local download_url="https://releases.hashicorp.com/terraform/${latest_version}/terraform_${latest_version}_linux_${arch}.zip"
    local checksum_url="https://releases.hashicorp.com/terraform/${latest_version}/terraform_${latest_version}_SHA256SUMS"
    
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
        temp_dir=$(create_secure_temp_dir "terraform")
    else
        temp_dir=$(mktemp -d)
        chmod 700 "$temp_dir"
    fi
    
    local zip_file="$temp_dir/terraform_${latest_version}_linux_${arch}.zip"
    local checksum_file="$temp_dir/terraform_${latest_version}_SHA256SUMS"
    
    # Download Terraform archive using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v download_file >/dev/null 2>&1; then
        if ! download_file "$download_url" "$zip_file"; then
            log_error "Failed to download Terraform archive"
            rm -rf "$temp_dir"
            return 1
        fi
        if ! download_file "$checksum_url" "$checksum_file"; then
            log_error "Failed to download checksums"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        # Fallback download
        log_info "Downloading Terraform..."
        if ! curl -fsSL -o "$zip_file" "$download_url"; then
            log_error "Download failed with curl"
            rm -rf "$temp_dir"
            return 1
        fi
        if ! curl -fsSL -o "$checksum_file" "$checksum_url"; then
            log_error "Checksum download failed with curl"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # Verify checksum
    log_info "Verifying checksum..."
    cd "$temp_dir"
    local zip_filename="terraform_${latest_version}_linux_${arch}.zip"
    local expected_checksum
    expected_checksum=$(grep "$zip_filename" "$checksum_file" | cut -d' ' -f1)
    local actual_checksum
    actual_checksum=$(sha256sum "$zip_filename" | cut -d' ' -f1)
    
    if [ "$expected_checksum" != "$actual_checksum" ]; then
        log_error "Checksum verification failed"
        log_error "Expected: $expected_checksum"
        log_error "Actual: $actual_checksum"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_debug "Checksum verification passed"
    
    # Extract Terraform
    log_info "Extracting Terraform..."
    if ! unzip -q "$zip_filename"; then
        log_error "Failed to extract Terraform archive"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Install Terraform
    if [ ! -f "$temp_dir/terraform" ]; then
        log_error "Terraform binary not found in extracted archive"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_info "Installing Terraform to /usr/local/bin/..."
    sudo mv "$temp_dir/terraform" "/usr/local/bin/$COMMAND_NAME"
    sudo chmod +x "/usr/local/bin/$COMMAND_NAME"
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "$COMMAND_NAME --help" "Terraform"; then
            local installed_version
            installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            
            # Setup completion and show usage info
            setup_terraform_completion
            show_terraform_usage_info
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local installed_version
            installed_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
            log_success "$SOFTWARE_NAME installed successfully (version: $installed_version)"
            
            # Setup completion and show usage info
            setup_terraform_completion
            show_terraform_usage_info
            return 0
        else
            log_error "$SOFTWARE_NAME installation verification failed"
            return 1
        fi
    fi
}

# Helper function for Terraform bash completion
setup_terraform_completion() {
    if command -v terraform >/dev/null 2>&1 && [ -d /etc/bash_completion.d ]; then
        log_info "Setting up Terraform bash completion..."
        if terraform -install-autocomplete 2>/dev/null; then
            log_debug "Terraform bash completion configured"
        else
            log_warn "Failed to configure Terraform bash completion"
        fi
    fi
}

# Helper function to show usage information
show_terraform_usage_info() {
    log_info "To get started with Terraform:"
    log_info "  terraform init              # Initialize a working directory"
    log_info "  terraform plan              # Create an execution plan"
    log_info "  terraform apply             # Execute the plan"
    log_info "  terraform --help            # Show help"
    log_info ""
    log_info "Documentation: https://www.terraform.io/docs/"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_terraform
fi
