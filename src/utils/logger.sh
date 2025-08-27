#!/bin/bash

# logger.sh - Logging utilities for WSL installation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Default log level
CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# Log directory - use BASH_SOURCE to get the correct path relative to this logger script
if [ -n "${BASH_SOURCE[0]}" ]; then
    LOGGER_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
    if [ "$LOGGER_SCRIPT_DIR" = "${BASH_SOURCE[0]}" ]; then
        LOGGER_SCRIPT_DIR="."
    fi
    LOGGER_SCRIPT_DIR="$(cd "$LOGGER_SCRIPT_DIR" && pwd)"
    DEFAULT_LOG_DIR="$LOGGER_SCRIPT_DIR/../logs"
else
    # Fallback for when BASH_SOURCE is not available
    DEFAULT_LOG_DIR="$(pwd)/logs"
fi

LOG_DIR="${LOG_DIR:-$DEFAULT_LOG_DIR}"

# Use the run ID from the main script if available, otherwise generate a new timestamp
if [ -n "$WSL_INSTALL_RUN_ID" ]; then
    # When running from temp directory, write log to /tmp for better performance
    if [ -n "$WSL_INSTALL_TEMP_MODE" ]; then
        LOG_FILE="${LOG_FILE:-/tmp/wsl-install-log-$WSL_INSTALL_RUN_ID.log}"
    else
        LOG_FILE="${LOG_FILE:-$LOG_DIR/wsl-installation-$WSL_INSTALL_RUN_ID.log}"
    fi
else
    if [ -n "$WSL_INSTALL_TEMP_MODE" ]; then
        LOG_FILE="${LOG_FILE:-/tmp/wsl-install-log-$(date +%Y%m%d_%H%M%S).log}"
    else
        LOG_FILE="${LOG_FILE:-$LOG_DIR/wsl-installation-$(date +%Y%m%d_%H%M%S).log}"
    fi
fi

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Function to get timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Function to get log level name
get_log_level_name() {
    case $1 in
        $LOG_LEVEL_DEBUG) echo "DEBUG" ;;
        $LOG_LEVEL_INFO) echo "INFO" ;;
        $LOG_LEVEL_WARN) echo "WARN" ;;
        $LOG_LEVEL_ERROR) echo "ERROR" ;;
        *) echo "UNKNOWN" ;;
    esac
}

# Core logging function
log_message() {
    local level=$1
    local message=$2
    local color=$3
    
    if [ "$level" -ge "$CURRENT_LOG_LEVEL" ]; then
        local timestamp=$(get_timestamp)
        local level_name=$(get_log_level_name "$level")
        
        # Console output with color
        if [ -n "$color" ] && [ -t 1 ]; then
            echo -e "${color}[$timestamp] [$level_name] $message${NC}"
        else
            echo "[$timestamp] [$level_name] $message"
        fi
        
        # File output without color
        echo "[$timestamp] [$level_name] $message" >> "$LOG_FILE"
    fi
}

# Convenience functions
log_debug() {
    log_message $LOG_LEVEL_DEBUG "$1" "$PURPLE"
}

log_info() {
    log_message $LOG_LEVEL_INFO "$1" "$BLUE"
}

log_success() {
    log_message $LOG_LEVEL_INFO "$1" "$GREEN"
}

log_warn() {
    log_message $LOG_LEVEL_WARN "$1" "$YELLOW"
}

log_error() {
    log_message $LOG_LEVEL_ERROR "$1" "$RED"
}

# Function to log command execution
log_command() {
    local cmd="$1"
    log_debug "Executing: $cmd"
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_debug "Command succeeded: $cmd"
        return 0
    else
        local exit_code=$?
        log_error "Command failed with exit code $exit_code: $cmd"
        return $exit_code
    fi
}

# Function to log section headers
log_section() {
    local section="$1"
    local separator="=================================="
    log_info ""
    log_info "$separator"
    log_info "$section"
    log_info "$separator"
}

# Function to log installation start
log_install_start() {
    local software="$1"
    log_info "📦 Installing $software..."
}

# Function to log installation success
log_install_success() {
    local software="$1"
    log_success "✅ Successfully installed $software"
}

# Function to log installation failure
log_install_failure() {
    local software="$1"
    local error="$2"
    log_error "❌ Failed to install $software: $error"
}

# Function to log skipped installation
log_install_skip() {
    local software="$1"
    local reason="$2"
    log_warn "⏭️  Skipping $software: $reason"
}

# Function to set log level from string
set_log_level() {
    case "${1^^}" in
        "DEBUG") CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        "INFO") CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        "WARN") CURRENT_LOG_LEVEL=$LOG_LEVEL_WARN ;;
        "ERROR") CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        *) log_warn "Unknown log level: $1. Using INFO." ;;
    esac
}

# Function to show all files related to current run
show_run_files() {
    if [ -n "$WSL_INSTALL_RUN_ID" ]; then
        log_info "Files for run ID $WSL_INSTALL_RUN_ID:"
        find "$LOG_DIR" -name "*$WSL_INSTALL_RUN_ID*" 2>/dev/null | while read -r file; do
            if [ -f "$file" ]; then
                log_info "  📄 $(basename "$file")"
            fi
        done
    else
        log_warn "No run ID set. Cannot show related files."
    fi
}

# Initialize logging
if [ -n "$WSL_INSTALL_RUN_ID" ] && [ -z "$WSL_LOGGING_INITIALIZED" ]; then
    export WSL_LOGGING_INITIALIZED=true
    log_info "==============================================="
    log_info "WSL Installation Run ID: $WSL_INSTALL_RUN_ID"
    log_info "==============================================="
fi

# Only log initialization message if not already initialized
if [ -z "$WSL_LOGGER_READY" ]; then
    export WSL_LOGGER_READY=true
    log_info "Logging initialized. Log file: $LOG_FILE"
fi
