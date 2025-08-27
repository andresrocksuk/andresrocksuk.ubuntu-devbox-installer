#!/bin/bash

# copy-to-temp.sh - Copy WSL installation files to temp directory for better performance
# This script is called by install-wsl.ps1 to copy files from /mnt/c/ to /tmp/

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
if [ $# -ne 2 ]; then
    log_error "Usage: $0 <source_path> <temp_directory>"
    log_error "Example: $0 /mnt/c/Users/user/wsl /tmp/wsl-install-20250824_123456"
    exit 1
fi

SOURCE_PATH="$1"
TEMP_DIR="$2"

log_info "Starting copy operation..."
log_info "Source: $SOURCE_PATH"
log_info "Destination: $TEMP_DIR"

# Validate source path exists
if [ ! -d "$SOURCE_PATH" ]; then
    log_error "Source path does not exist: $SOURCE_PATH"
    exit 1
fi

# Validate source contains install.sh
if [ ! -f "$SOURCE_PATH/install.sh" ]; then
    log_error "install.sh not found in source path: $SOURCE_PATH"
    exit 1
fi

# Remove existing temp directory if it exists
if [ -d "$TEMP_DIR" ]; then
    log_info "Removing existing temp directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
fi

# Create new temp directory
log_info "Creating temp directory: $TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Copy files excluding unnecessary directories and files
log_info "Copying files with exclusions..."
rsync -av \
    --exclude='.git' \
    --exclude='docs' \
    --exclude='examples' \
    --exclude='logs' \
    --exclude='.gitignore' \
    --exclude='*.md' \
    --exclude='README.md' \
    --exclude='*.prompt.md' \
    --exclude='.vscode' \
    --exclude='node_modules' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='*.tmp' \
    --exclude='*.log' \
    "$SOURCE_PATH/" "$TEMP_DIR/"

# Ensure all shell scripts are executable
log_info "Setting executable permissions for shell scripts..."
find "$TEMP_DIR" -name "*.sh" -type f -exec chmod +x {} \;

# Verify install.sh exists and is executable
if [ -f "$TEMP_DIR/install.sh" ]; then
    chmod +x "$TEMP_DIR/install.sh"
    log_success "install.sh found and made executable"
else
    log_error "install.sh not found in temp directory after copy"
    exit 1
fi

# Verify utils directory and scripts
if [ -d "$TEMP_DIR/utils" ]; then
    chmod +x "$TEMP_DIR/utils"/*.sh 2>/dev/null || true
    log_info "Utils directory scripts made executable"
    
    # Verify critical utility scripts exist
    CRITICAL_SCRIPTS=("logger.sh" "package-manager.sh" "version-checker.sh" "stream-logs.sh")
    for script in "${CRITICAL_SCRIPTS[@]}"; do
        if [ -f "$TEMP_DIR/utils/$script" ]; then
            chmod +x "$TEMP_DIR/utils/$script"
            log_info "✓ $script found and made executable"
        else
            log_error "✗ Critical script not found: $script"
        fi
    done
else
    log_error "utils directory not found in temp directory"
    exit 1
fi

# Verify software-scripts directory
if [ -d "$TEMP_DIR/software-scripts" ]; then
    find "$TEMP_DIR/software-scripts" -name "*.sh" -type f -exec chmod +x {} \;
    log_info "Software scripts made executable"
else
    log_error "software-scripts directory not found in temp directory"
    exit 1
fi

# Display copy summary
COPIED_FILES=$(find "$TEMP_DIR" -type f | wc -l)
COPIED_DIRS=$(find "$TEMP_DIR" -type d | wc -l)
EXECUTABLE_SCRIPTS=$(find "$TEMP_DIR" -name "*.sh" -type f | wc -l)

log_success "Copy operation completed successfully!"
log_info "Summary:"
log_info "  - Files copied: $COPIED_FILES"
log_info "  - Directories created: $COPIED_DIRS"
log_info "  - Executable scripts: $EXECUTABLE_SCRIPTS"
log_info "  - Temp directory: $TEMP_DIR"

exit 0
