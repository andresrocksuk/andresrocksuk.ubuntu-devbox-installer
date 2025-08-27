#!/bin/bash

# stream-logs.sh - Stream installation logs to both temp and Windows mount locations
# This script runs in parallel with the installation to provide real-time log monitoring

set -e  # Exit on any error

# Function to log messages
log_info() {
    echo "[STREAM] $1"
}

log_error() {
    echo "[STREAM ERROR] $1" >&2
}

# Check if required parameters are provided
if [ $# -ne 3 ]; then
    log_error "Usage: $0 <run_id> <windows_log_path> <temp_log_file>"
    log_error "Example: $0 20250824_123456 /mnt/c/Users/user/wsl/logs /tmp/wsl-install-log-20250824_123456.log"
    exit 1
fi

RUN_ID="$1"
WINDOWS_LOG_PATH="$2"
TEMP_LOG_FILE="$3"

# Derived paths
WINDOWS_LOG_FILE="$WINDOWS_LOG_PATH/wsl-installation-$RUN_ID.log"

log_info "Starting log streaming..."
log_info "Run ID: $RUN_ID"
log_info "Temp log file: $TEMP_LOG_FILE"
log_info "Windows log file: $WINDOWS_LOG_FILE"

# Ensure Windows log directory exists
mkdir -p "$WINDOWS_LOG_PATH"

# Initialize both log files with headers
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "=== WSL Installation Log Stream Started at $TIMESTAMP ===" > "$WINDOWS_LOG_FILE"
echo "Run ID: $RUN_ID" >> "$WINDOWS_LOG_FILE"
echo "Temp Log: $TEMP_LOG_FILE" >> "$WINDOWS_LOG_FILE"
echo "Windows Log: $WINDOWS_LOG_FILE" >> "$WINDOWS_LOG_FILE"
echo "=================================================" >> "$WINDOWS_LOG_FILE"
echo "" >> "$WINDOWS_LOG_FILE"

# Wait for the temp log file to be created (with timeout)
WAIT_TIMEOUT=30
WAIT_COUNT=0
while [ ! -f "$TEMP_LOG_FILE" ] && [ $WAIT_COUNT -lt $WAIT_TIMEOUT ]; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ ! -f "$TEMP_LOG_FILE" ]; then
    log_error "Timeout waiting for temp log file to be created: $TEMP_LOG_FILE"
    echo "[ERROR] Timeout waiting for installation to start" >> "$WINDOWS_LOG_FILE"
    exit 1
fi

log_info "Temp log file detected, starting real-time streaming..."

# Stream the log file contents in real-time using tail
# This will continuously copy new lines from temp log to Windows log
tail -f "$TEMP_LOG_FILE" >> "$WINDOWS_LOG_FILE" &
TAIL_PID=$?

# Function to cleanup on exit
cleanup() {
    log_info "Cleaning up log streaming..."
    if [ -n "$TAIL_PID" ]; then
        kill $TAIL_PID 2>/dev/null || true
    fi
    
    # Final sync to ensure all content is copied
    if [ -f "$TEMP_LOG_FILE" ]; then
        log_info "Performing final log sync..."
        cat "$TEMP_LOG_FILE" > "$WINDOWS_LOG_FILE.final"
        mv "$WINDOWS_LOG_FILE.final" "$WINDOWS_LOG_FILE"
    fi
    
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "" >> "$WINDOWS_LOG_FILE"
    echo "=== Log Stream Ended at $TIMESTAMP ===" >> "$WINDOWS_LOG_FILE"
}

# Set up signal handlers for cleanup
trap cleanup EXIT INT TERM

# Monitor the installation process
# We'll check if the installation is still running by monitoring the temp log file
LAST_SIZE=0
STALE_COUNT=0
MAX_STALE_CHECKS=60  # 5 minutes of no activity

while true; do
    if [ -f "$TEMP_LOG_FILE" ]; then
        CURRENT_SIZE=$(stat -f%z "$TEMP_LOG_FILE" 2>/dev/null || stat -c%s "$TEMP_LOG_FILE" 2>/dev/null || echo "0")
        
        if [ "$CURRENT_SIZE" -gt "$LAST_SIZE" ]; then
            # File is growing, reset stale counter
            STALE_COUNT=0
            LAST_SIZE=$CURRENT_SIZE
        else
            # File hasn't grown, increment stale counter
            STALE_COUNT=$((STALE_COUNT + 1))
        fi
        
        # Check if installation might be complete based on log content
        if grep -q "Installation script completed" "$TEMP_LOG_FILE" 2>/dev/null; then
            log_info "Installation completion detected in log"
            sleep 2  # Give a moment for any final writes
            break
        fi
        
        # Check for excessive staleness (installation might have failed)
        if [ $STALE_COUNT -gt $MAX_STALE_CHECKS ]; then
            log_info "No log activity for 5+ minutes, assuming installation finished"
            break
        fi
    else
        log_error "Temp log file disappeared: $TEMP_LOG_FILE"
        break
    fi
    
    sleep 5
done

log_info "Log streaming completed"
exit 0
