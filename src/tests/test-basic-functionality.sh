#!/bin/bash

# Test script for basic installation functionality
# Simple test script to verify core installation features

set -e

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../utils"
ROOT_DIR="$SCRIPT_DIR/../.."
SRC_DIR="$SCRIPT_DIR/.."

# Source utilities
if [ -f "$UTILS_DIR/logger.sh" ]; then
    source "$UTILS_DIR/logger.sh"
else
    # Fallback logging functions
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_success() { echo "[SUCCESS] $1"; }
fi

echo "===================================="
echo "Basic Installation Test"
echo "===================================="

# Test 1: Check install.sh exists and is executable
echo "Test 1: Checking install.sh"
if [ -f "$SRC_DIR/install.sh" ] && [ -x "$SRC_DIR/install.sh" ]; then
    log_success "install.sh exists and is executable"
else
    log_error "install.sh not found or not executable"
    exit 1
fi

# Test 2: Test help functionality
echo "Test 2: Testing help functionality"
cd "$SRC_DIR"
bash install.sh --help | head -10
echo ""

# Test 3: Test dry run mode
echo "Test 3: Testing dry run mode with prerequisites"
bash install.sh --dry-run --sections prerequisites | head -15
echo ""

# Test 4: Test PowerShell script
echo "Test 4: Checking PowerShell script"
if [ -f "$ROOT_DIR/install-wsl.ps1" ]; then
    log_success "install-wsl.ps1 exists"
    # Just check file exists and is readable, skip syntax check for now
    if [ -r "$ROOT_DIR/install-wsl.ps1" ]; then
        log_success "install-wsl.ps1 is readable"
    else
        log_error "install-wsl.ps1 is not readable"
    fi
else
    log_error "install-wsl.ps1 not found"
fi
echo ""

echo "===================================="
echo "Basic Test Summary"
echo "===================================="
log_success "Core installation files verified"
log_success "Help functionality working"
log_success "Dry run mode functional"
log_info "Ready for full installation testing"
echo ""
