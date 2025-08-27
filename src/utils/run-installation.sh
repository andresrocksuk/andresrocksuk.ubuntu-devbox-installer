#!/bin/bash

# run-installation.sh - Execute WSL installation from temp directory
# This script is called by install-wsl.ps1 to run the installation with proper environment setup

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
if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    log_error "Usage: $0 <temp_script_dir> <run_id> <log_path> [config_args]"
    log_error "Example: $0 /tmp/wsl-install-20250824_123456 20250824_123456 /mnt/c/Users/user/wsl/logs"
    log_error "Example with config: $0 /tmp/wsl-install-20250824_123456 20250824_123456 /mnt/c/Users/user/wsl/logs '--config prerequisites,apt_packages'"
    exit 1
fi

TEMP_SCRIPT_DIR="$1"
RUN_ID="$2"
LOG_PATH="$3"
CONFIG_ARGS="$4"

# Define log file paths
LOG_FILE="/tmp/wsl-install-log-$RUN_ID.log"
DEST_LOG_FILE="$LOG_PATH/wsl-installation-$RUN_ID.log"

log_info "Starting WSL installation execution..."
log_info "Temp directory: $TEMP_SCRIPT_DIR"
log_info "Run ID: $RUN_ID"
log_info "Log path: $LOG_PATH"
log_info "Config args: $CONFIG_ARGS"

# Validate temp directory exists and contains install.sh
if [ ! -d "$TEMP_SCRIPT_DIR" ]; then
    log_error "Temp script directory does not exist: $TEMP_SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$TEMP_SCRIPT_DIR/install.sh" ]; then
    log_error "install.sh not found in temp directory: $TEMP_SCRIPT_DIR"
    exit 1
fi

# Set environment variables
export WSL_INSTALL_RUN_ID="$RUN_ID"
export WSL_INSTALL_TEMP_MODE='1'

log_info "Environment variables set:"
log_info "  WSL_INSTALL_RUN_ID=$WSL_INSTALL_RUN_ID"
log_info "  WSL_INSTALL_TEMP_MODE=$WSL_INSTALL_TEMP_MODE"

# Ensure the Windows logs directory exists from WSL side
log_info "Ensuring log directory exists: $LOG_PATH"
mkdir -p "$LOG_PATH"

# Start log streaming in background for real-time monitoring
LOG_FILE="/tmp/wsl-install-log-$RUN_ID.log"
STREAM_SCRIPT="$TEMP_SCRIPT_DIR/utils/stream-logs.sh"

if [ -f "$STREAM_SCRIPT" ]; then
    log_info "Starting log streaming for real-time monitoring..."
    bash "$STREAM_SCRIPT" "$RUN_ID" "$LOG_PATH" "$LOG_FILE" &
    STREAM_PID=$!
    log_info "Log streaming started with PID: $STREAM_PID"
else
    log_error "Log streaming script not found: $STREAM_SCRIPT"
    STREAM_PID=""
fi

# Change to temp directory and run the installation script
log_info "Changing to temp directory and starting installation..."
cd "$TEMP_SCRIPT_DIR"

# Verify we're in the right directory
if [ "$(pwd)" != "$TEMP_SCRIPT_DIR" ]; then
    log_error "Failed to change to temp directory"
    exit 1
fi

# Make sure install.sh is executable
chmod +x ./install.sh

# Run the installation script
log_info "Executing ./install.sh with config args: $CONFIG_ARGS"
if [ -n "$CONFIG_ARGS" ]; then
    bash ./install.sh $CONFIG_ARGS
else
    bash ./install.sh
fi

# Get the exit code from install.sh
INSTALL_EXIT_CODE=$?
log_info "Installation script completed with exit code: $INSTALL_EXIT_CODE"

# Copy log file back to Windows mount if it exists
if [ -f "$LOG_FILE" ]; then
    log_info "Ensuring final log file copy from $LOG_FILE to $DEST_LOG_FILE"
    
    # Stop the streaming process if it's running
    if [ -n "$STREAM_PID" ]; then
        log_info "Stopping log streaming process (PID: $STREAM_PID)..."
        kill $STREAM_PID 2>/dev/null || true
        sleep 2  # Give it time to finish final sync
    fi
    
    # Ensure the final log is copied (streaming should have handled this, but double-check)
    if [ ! -f "$DEST_LOG_FILE" ] || [ "$LOG_FILE" -nt "$DEST_LOG_FILE" ]; then
        log_info "Performing final log copy..."
        cp "$LOG_FILE" "$DEST_LOG_FILE"
        if [ $? -eq 0 ]; then
            log_success "Final log file copy completed"
        else
            log_error "Failed to copy final log file"
        fi
    else
        log_success "Log file already up to date via streaming"
    fi
else
    log_error "Log file not found: $LOG_FILE"
    
    # Stop streaming process anyway
    if [ -n "$STREAM_PID" ]; then
        kill $STREAM_PID 2>/dev/null || true
    fi
fi

# Clean up temp directory using dedicated script if available
if [ -f "$TEMP_SCRIPT_DIR/utils/cleanup-temp.sh" ]; then
    log_info "Using dedicated cleanup script..."
    bash "$TEMP_SCRIPT_DIR/utils/cleanup-temp.sh" "$TEMP_SCRIPT_DIR"
    CLEANUP_EXIT_CODE=$?
    if [ $CLEANUP_EXIT_CODE -eq 0 ]; then
        log_success "Cleanup completed successfully"
    else
        log_error "Cleanup script failed with exit code: $CLEANUP_EXIT_CODE"
    fi
else
    # Fallback cleanup if script not found
    log_info "Cleanup script not found, using fallback cleanup..."
    cd /tmp
    rm -rf "$TEMP_SCRIPT_DIR"
    if [ $? -eq 0 ]; then
        log_success "Fallback cleanup completed"
    else
        log_error "Fallback cleanup failed"
    fi
fi

# Exit with the same code as install.sh
log_info "Exiting with install.sh exit code: $INSTALL_EXIT_CODE"
exit $INSTALL_EXIT_CODE
