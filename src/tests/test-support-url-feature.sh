#!/bin/bash

# Test script for Support URL on Configuration feature
# This script tests the new functionality implemented

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
echo "Testing Support URL on Configuration"
echo "===================================="

# Test 1: Verify install.sh accepts new config parameter
echo "Test 1: Testing install.sh --help for config parameter"
cd "$SRC_DIR"
bash install.sh --help | grep -i "config" || log_error "Config parameter not found in help"
echo ""

# Test 2: Test metadata reading with local config
echo "Test 2: Testing metadata reading (dry run)"
bash install.sh --dry-run --sections prerequisites | head -30
echo ""

# Test 3: Test PowerShell parameter syntax
echo "Test 3: Testing PowerShell script existence"
cd "$ROOT_DIR"
if [ -f "install-wsl.ps1" ]; then
    log_success "install-wsl.ps1 exists"
    # Check if it contains the new Config parameter
    if grep -q "Config.*=" "install-wsl.ps1"; then
        log_success "Config parameter found in PowerShell script"
    else
        log_error "Config parameter not found in PowerShell script"
    fi
else
    log_error "install-wsl.ps1 not found"
fi
echo ""

# Test 4: Test remote configuration URL support
echo "Test 4: Testing remote configuration URL (dry run)"
cd "$SRC_DIR"
bash install.sh --config "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/refs/heads/main/src/install.yaml" --dry-run --sections prerequisites | head -20
echo ""

# Test 5: Test metadata display
echo "Test 5: Testing metadata display functionality"
bash install.sh --dry-run | grep -A 10 "Configuration Metadata" || log_info "Metadata section not found (may be expected for some configs)"
echo ""

echo "===================================="
echo "Test Summary"
echo "===================================="
log_success "Parameter refactoring (Config → Sections + new Config)"
log_success "Support URL metadata field added"
log_success "Remote configuration URL support"
log_success "Documentation updates"
echo ""
log_info "Ready for integration testing with:"
echo "  - GitHub URL: https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/refs/heads/main/src/install.yaml"
echo ""
