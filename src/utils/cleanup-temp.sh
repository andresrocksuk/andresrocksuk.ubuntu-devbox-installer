#!/bin/bash

# cleanup-temp.sh - Clean up temporary installation directory
# This script is called by install-wsl.ps1 to clean up after installation

set -e  # Exit on any error

# Function to log messages
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_success() {
    echo "[SUCCESS] $1"
}

# Check if required parameters are provided
if [ $# -ne 1 ]; then
    log_error "Usage: $0 <temp_directory>"
    log_error "Example: $0 /tmp/wsl-install-20250824_123456"
    exit 1
fi

TEMP_DIR="$1"

log_info "Starting cleanup operation..."
log_info "Target directory: $TEMP_DIR"

# Validate temp directory exists and is in /tmp
if [ ! -d "$TEMP_DIR" ]; then
    log_info "Temp directory does not exist (already cleaned up?): $TEMP_DIR"
    exit 0
fi

# Safety check - ensure we're only deleting from /tmp
if [[ ! "$TEMP_DIR" =~ ^/tmp/wsl-install- ]]; then
    log_error "Safety check failed: Directory is not in expected /tmp/wsl-install- pattern"
    log_error "Refusing to delete: $TEMP_DIR"
    exit 1
fi

# Get directory size before cleanup
if command -v du >/dev/null 2>&1; then
    DIR_SIZE=$(du -sh "$TEMP_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    log_info "Directory size: $DIR_SIZE"
fi

# Remove the temp directory
log_info "Removing temp directory..."
rm -rf "$TEMP_DIR"

# Verify removal
if [ -d "$TEMP_DIR" ]; then
    log_error "Failed to remove temp directory: $TEMP_DIR"
    exit 1
else
    log_success "Temp directory cleaned up successfully"
fi

exit 0
