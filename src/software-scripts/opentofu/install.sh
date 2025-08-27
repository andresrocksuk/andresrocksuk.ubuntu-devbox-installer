#!/bin/bash

# OpenTofu Installation Script
# This script installs the latest OpenTofu (open-source Terraform alternative)

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
    log_info "Running OpenTofu installation script in standalone mode"
fi

# Check if OpenTofu is already installed
if command -v tofu >/dev/null 2>&1; then
    current_version=$(tofu version -json 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    log_info "OpenTofu is already installed (version: $current_version)"
    
    # Get latest version from GitHub API
    log_info "Checking for latest OpenTofu version..."
    latest_version=$(curl -s https://api.github.com/repos/opentofu/opentofu/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4 | cut -d'v' -f2)
    
    if [ "$current_version" = "$latest_version" ]; then
        log_success "OpenTofu is already up to date (version: $current_version)"
        exit 0
    else
        log_info "Newer version available: $latest_version (current: $current_version)"
        log_info "Proceeding with update..."
    fi
fi

log_info "Installing OpenTofu..."

# Check prerequisites
if ! command -v curl >/dev/null 2>&1; then
    log_error "curl is required but not installed"
    exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
    log_error "unzip is required but not installed"
    exit 1
fi

# Get the latest version from GitHub API
log_info "Fetching latest OpenTofu version..."
latest_version_tag=$(curl -s https://api.github.com/repos/opentofu/opentofu/releases/latest | grep -o '"tag_name": "v[^"]*"' | cut -d'"' -f4)
latest_version=$(echo "$latest_version_tag" | cut -d'v' -f2)

if [ -z "$latest_version" ]; then
    log_error "Failed to fetch latest OpenTofu version"
    exit 1
fi

log_info "Latest OpenTofu version: $latest_version"

# Construct download URL
download_url="https://github.com/opentofu/opentofu/releases/download/${latest_version_tag}/tofu_${latest_version}_linux_amd64.zip"
checksum_url="https://github.com/opentofu/opentofu/releases/download/${latest_version_tag}/tofu_${latest_version}_SHA256SUMS"

# Create temporary directory
temp_dir=$(mktemp -d)
cd "$temp_dir"


# Download OpenTofu
log_info "Downloading OpenTofu..."
curl -sLO "$download_url"

# Download checksums
log_info "Downloading checksums..."
curl -sLO "$checksum_url"

# Verify checksum
log_info "Verifying checksum..."
if ! sha256sum -c --ignore-missing "tofu_${latest_version}_SHA256SUMS"; then
    log_error "Checksum verification failed"
    cd /
    rm -rf "$temp_dir"
    exit 1
fi

log_success "Checksum verification passed"

# Extract OpenTofu
log_info "Extracting OpenTofu..."
unzip -q "tofu_${latest_version}_linux_amd64.zip"

# Install OpenTofu
log_info "Installing OpenTofu to /usr/local/bin/..."
sudo mv tofu /usr/local/bin/

# Make it executable
sudo chmod +x /usr/local/bin/tofu

# Clean up
cd /
rm -rf "$temp_dir"

# Verify installation
if command -v tofu >/dev/null 2>&1; then
    version=$(tofu version -json 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    log_success "OpenTofu installed successfully (version: $version)"
    
    # Show basic usage info
    log_info ""
    log_info "To get started with OpenTofu:"
    log_info "  tofu init                   # Initialize a working directory"
    log_info "  tofu plan                   # Create an execution plan"
    log_info "  tofu apply                  # Execute the plan"
    log_info "  tofu --help                 # Show help"
    log_info ""
    log_info "OpenTofu is Terraform-compatible and supports the same syntax and workflows."
    log_info "Documentation: https://opentofu.org/docs/"
else
    log_error "OpenTofu installation failed"
    exit 1
fi
