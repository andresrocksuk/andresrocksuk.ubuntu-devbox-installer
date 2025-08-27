#!/bin/bash

# Terraform Installation Script
# This script installs the latest Terraform

set -e

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WSL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities if available (for integration with main installer)
if [ -f "$WSL_DIR/utils/logger.sh" ]; then
    source "$WSL_DIR/utils/logger.sh"
else
    # Standalone logging functions
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_debug() { echo "[DEBUG] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
fi

# Standalone execution support
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    log_info "Running Terraform installation script in standalone mode"
fi

# Check if Terraform is already installed
if command -v terraform >/dev/null 2>&1; then
    current_version=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)
    log_info "Terraform is already installed (version: $current_version)"
    
    # Get latest version from HashiCorp API
    log_info "Checking for latest Terraform version..."
    latest_version=$(curl -s https://api.releases.hashicorp.com/v1/releases/terraform | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ "$current_version" = "$latest_version" ]; then
        log_success "Terraform is already up to date (version: $current_version)"
        exit 0
    else
        log_info "Newer version available: $latest_version (current: $current_version)"
        log_info "Proceeding with update..."
    fi
fi

log_info "Installing Terraform..."

# Check prerequisites
if ! command -v curl >/dev/null 2>&1; then
    log_error "curl is required but not installed"
    exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
    log_error "unzip is required but not installed"
    exit 1
fi

# Get the latest version from HashiCorp API
log_info "Fetching latest Terraform version..."
latest_version=$(curl -s https://api.releases.hashicorp.com/v1/releases/terraform | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest Terraform version"
    exit 1
fi

log_info "Latest Terraform version: $latest_version"

# Construct download URL
download_url="https://releases.hashicorp.com/terraform/${latest_version}/terraform_${latest_version}_linux_amd64.zip"
checksum_url="https://releases.hashicorp.com/terraform/${latest_version}/terraform_${latest_version}_SHA256SUMS"

# Create temporary directory
temp_dir=$(mktemp -d)
cd "$temp_dir"

# Download Terraform
log_info "Downloading Terraform..."
curl -sLO "$download_url"

# Download checksums
log_info "Downloading checksums..."
curl -sLO "$checksum_url"

# Verify checksum
log_info "Verifying checksum..."
expected_checksum=$(grep "terraform_${latest_version}_linux_amd64.zip" terraform_${latest_version}_SHA256SUMS | cut -d' ' -f1)
actual_checksum=$(sha256sum "terraform_${latest_version}_linux_amd64.zip" | cut -d' ' -f1)

if [ "$expected_checksum" != "$actual_checksum" ]; then
    log_error "Checksum verification failed"
    log_error "Expected: $expected_checksum"
    log_error "Actual: $actual_checksum"
    cd /
    rm -rf "$temp_dir"
    exit 1
fi

log_success "Checksum verification passed"

# Extract Terraform
log_info "Extracting Terraform..."
unzip -q "terraform_${latest_version}_linux_amd64.zip"

# Install Terraform
log_info "Installing Terraform to /usr/local/bin/..."
sudo mv terraform /usr/local/bin/

# Make it executable
sudo chmod +x /usr/local/bin/terraform

# Clean up
cd /
rm -rf "$temp_dir"

# Verify installation
if command -v terraform >/dev/null 2>&1; then
    version=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)
    log_success "Terraform installed successfully (version: $version)"
    
    # Enable bash completion if bash-completion is installed
    if command -v terraform >/dev/null 2>&1 && [ -d /etc/bash_completion.d ]; then
        log_info "Setting up Terraform bash completion..."
        terraform -install-autocomplete 2>/dev/null || true
    fi
    
    # Show basic usage info
    log_info "To get started with Terraform:"
    log_info "  terraform init              # Initialize a working directory"
    log_info "  terraform plan              # Create an execution plan"
    log_info "  terraform apply             # Execute the plan"
    log_info "  terraform --help            # Show help"
    log_info ""
    log_info "Documentation: https://www.terraform.io/docs/"
else
    log_error "Terraform installation failed"
    exit 1
fi
