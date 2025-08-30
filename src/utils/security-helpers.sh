#!/bin/bash

# security-helpers.sh - Security utilities for safe parameter handling and input validation

# Handle being sourced from different directories
if [ -n "${BASH_SOURCE[0]}" ]; then
    SECURITY_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
    if [ "$SECURITY_SCRIPT_DIR" = "${BASH_SOURCE[0]}" ]; then
        SECURITY_SCRIPT_DIR="."
    fi
    SECURITY_SCRIPT_DIR="$(cd "$SECURITY_SCRIPT_DIR" && pwd)"
else
    SECURITY_SCRIPT_DIR="${0%/*}"
    if [ "$SECURITY_SCRIPT_DIR" = "$0" ]; then
        SECURITY_SCRIPT_DIR="."
    fi
    SECURITY_SCRIPT_DIR="$(cd "$SECURITY_SCRIPT_DIR" && pwd)"
fi

# Source required utilities
source "$SECURITY_SCRIPT_DIR/logger.sh"

# Function to validate and sanitize URL input
# Usage: validate_and_sanitize_url "url"
validate_and_sanitize_url() {
    local url="$1"
    
    # Check if URL is empty
    if [ -z "$url" ]; then
        log_error "URL cannot be empty"
        return 1
    fi
    
    # Check URL length (prevent extremely long URLs)
    if [ ${#url} -gt 2048 ]; then
        log_error "URL too long (max 2048 characters)"
        return 1
    fi
    
    # Basic URL validation - must start with http:// or https://
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "Invalid URL format: must start with http:// or https://"
        return 1
    fi
    
    # Check for common dangerous patterns
    local dangerous_patterns=(
        "localhost"
        "127\."
        "192\.168\."
        "10\."
        "172\.(1[6-9]|2[0-9]|3[01])\."
        "file://"
        "javascript:"
        "data:"
    )
    
    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$url" =~ $pattern ]]; then
            log_error "URL contains potentially dangerous pattern: $pattern"
            return 1
        fi
    done
    
    echo "$url"
    return 0
}

# Function to validate file path
# Usage: validate_file_path "path" ["allow_relative"]
validate_file_path() {
    local path="$1"
    local allow_relative="${2:-false}"
    
    # Check if path is empty
    if [ -z "$path" ]; then
        log_error "File path cannot be empty"
        return 1
    fi
    
    # Check path length
    if [ ${#path} -gt 4096 ]; then
        log_error "File path too long (max 4096 characters)"
        return 1
    fi
    
    # Check for dangerous characters and patterns
    if echo "$path" | grep -q '[;&|`$()\"'"'"'<>]'; then
        log_error "File path contains dangerous characters: $path"
        return 1
    fi
    
    # Check for directory traversal attempts
    if [[ "$path" =~ \.\./|\.\.\\ ]]; then
        log_error "File path contains directory traversal: $path"
        return 1
    fi
    
    # Check if relative paths are allowed
    if [ "$allow_relative" = "false" ] && [[ ! "$path" =~ ^/ ]]; then
        log_error "Relative paths not allowed: $path"
        return 1
    fi
    
    # Validate path characters (allow alphanumeric, -, _, ., /, ~)
    if [[ ! "$path" =~ ^[a-zA-Z0-9._/~-]+$ ]]; then
        log_error "File path contains invalid characters: $path"
        return 1
    fi
    
    echo "$path"
    return 0
}

# Function to validate version string
# Usage: validate_version_string "version"
validate_version_string() {
    local version="$1"
    
    # Check if version is empty
    if [ -z "$version" ]; then
        log_error "Version string cannot be empty"
        return 1
    fi
    
    # Check version length
    if [ ${#version} -gt 100 ]; then
        log_error "Version string too long (max 100 characters)"
        return 1
    fi
    
    # Allow semantic versioning, build numbers, and common version patterns
    # Examples: 1.2.3, v1.2.3, 1.2.3-alpha, 1.2.3+build123, latest, stable
    if [[ ! "$version" =~ ^[a-zA-Z0-9v._+-]+$ ]]; then
        log_error "Invalid version string format: $version"
        return 1
    fi
    
    echo "$version"
    return 0
}

# Function to validate command name
# Usage: validate_command_name "command"
validate_command_name() {
    local command="$1"
    
    # Check if command is empty
    if [ -z "$command" ]; then
        log_error "Command name cannot be empty"
        return 1
    fi
    
    # Check command length
    if [ ${#command} -gt 100 ]; then
        log_error "Command name too long (max 100 characters)"
        return 1
    fi
    
    # Allow only alphanumeric characters, hyphens, and underscores
    if [[ ! "$command" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid command name format: $command"
        return 1
    fi
    
    echo "$command"
    return 0
}

# Function to sanitize input for shell execution
# Usage: sanitize_shell_input "input"
sanitize_shell_input() {
    local input="$1"
    
    # Remove or escape potentially dangerous characters
    # Keep only alphanumeric, spaces, dots, hyphens, underscores, slashes
    local sanitized
    sanitized=$(echo "$input" | tr -cd 'a-zA-Z0-9 ._/-')
    
    # Remove multiple consecutive spaces
    sanitized=$(echo "$sanitized" | tr -s ' ')
    
    # Trim leading and trailing spaces
    sanitized=$(echo "$sanitized" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    echo "$sanitized"
}

# Function to create secure temporary directory
# Usage: create_secure_temp_dir ["prefix"]
create_secure_temp_dir() {
    local prefix="${1:-install}"
    
    # Validate prefix
    if [[ ! "$prefix" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid temp directory prefix: $prefix"
        return 1
    fi
    
    local temp_dir
    temp_dir=$(mktemp -d "/tmp/${prefix}.XXXXXX")
    
    if [ -z "$temp_dir" ] || [ ! -d "$temp_dir" ]; then
        log_error "Failed to create temporary directory"
        return 1
    fi
    
    # Set restrictive permissions (owner only)
    chmod 700 "$temp_dir"
    
    echo "$temp_dir"
    return 0
}

# Function to safely execute command with parameters
# Usage: safe_execute_command "command" "param1" "param2" ...
safe_execute_command() {
    local command="$1"
    shift
    
    # Validate command name
    if ! validate_command_name "$command" >/dev/null; then
        log_error "Invalid command for safe execution: $command"
        return 1
    fi
    
    # Check if command exists
    if ! command -v "$command" >/dev/null 2>&1; then
        log_error "Command not found: $command"
        return 1
    fi
    
    # Validate each parameter
    local params=()
    for param in "$@"; do
        # Check parameter length
        if [ ${#param} -gt 1000 ]; then
            log_error "Parameter too long (max 1000 characters): ${param:0:50}..."
            return 1
        fi
        
        # Check for dangerous characters in parameters
        if echo "$param" | grep -q '[;&|`$()\"'"'"'<>]'; then
            log_error "Parameter contains dangerous characters: $param"
            return 1
        fi
        
        params+=("$param")
    done
    
    # Execute command with parameters safely
    log_debug "Executing: $command ${params[*]}"
    "$command" "${params[@]}"
}

# Function to validate environment variable name
# Usage: validate_env_var_name "var_name"
validate_env_var_name() {
    local var_name="$1"
    
    # Check if variable name is empty
    if [ -z "$var_name" ]; then
        log_error "Environment variable name cannot be empty"
        return 1
    fi
    
    # Check variable name length
    if [ ${#var_name} -gt 100 ]; then
        log_error "Environment variable name too long (max 100 characters)"
        return 1
    fi
    
    # Validate variable name format (must start with letter or underscore, followed by alphanumeric or underscore)
    if [[ ! "$var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        log_error "Invalid environment variable name format: $var_name"
        return 1
    fi
    
    echo "$var_name"
    return 0
}

# Function to safely set environment variable
# Usage: safe_set_env_var "var_name" "value"
safe_set_env_var() {
    local var_name="$1"
    local value="$2"
    
    # Validate variable name
    if ! validate_env_var_name "$var_name" >/dev/null; then
        return 1
    fi
    
    # Check value length
    if [ ${#value} -gt 4096 ]; then
        log_error "Environment variable value too long (max 4096 characters)"
        return 1
    fi
    
    # Sanitize value (remove potential command injection attempts)
    local safe_value
    safe_value=$(sanitize_shell_input "$value")
    
    # Set the environment variable
    export "$var_name"="$safe_value"
    log_debug "Set environment variable: $var_name=$safe_value"
    
    return 0
}

# Function to validate package name
# Usage: validate_package_name "package_name"
validate_package_name() {
    local package_name="$1"
    
    # Check if package name is empty
    if [ -z "$package_name" ]; then
        log_error "Package name cannot be empty"
        return 1
    fi
    
    # Check package name length
    if [ ${#package_name} -gt 200 ]; then
        log_error "Package name too long (max 200 characters)"
        return 1
    fi
    
    # Allow package names with dots, hyphens, underscores, and alphanumeric characters
    # This covers most package naming conventions (apt, npm, pip, etc.)
    if [[ ! "$package_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid package name format: $package_name"
        return 1
    fi
    
    echo "$package_name"
    return 0
}

# Function to validate network port number
# Usage: validate_port_number "port"
validate_port_number() {
    local port="$1"
    
    # Check if port is empty
    if [ -z "$port" ]; then
        log_error "Port number cannot be empty"
        return 1
    fi
    
    # Check if port is numeric
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        log_error "Port must be numeric: $port"
        return 1
    fi
    
    # Check port range (1-65535)
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Port must be between 1 and 65535: $port"
        return 1
    fi
    
    echo "$port"
    return 0
}

# Function to cleanup temporary files and directories
# Usage: cleanup_temp_resources "path1" "path2" ...
cleanup_temp_resources() {
    for resource in "$@"; do
        if [ -n "$resource" ] && [[ "$resource" =~ ^/tmp/ ]]; then
            if [ -f "$resource" ]; then
                rm -f "$resource"
                log_debug "Cleaned up temporary file: $resource"
            elif [ -d "$resource" ]; then
                rm -rf "$resource"
                log_debug "Cleaned up temporary directory: $resource"
            fi
        fi
    done
}

# Function to check for required security tools
# Usage: check_security_prerequisites
check_security_prerequisites() {
    local missing_tools=()
    
    # Check for checksum verification tools
    if ! command -v sha256sum >/dev/null 2>&1; then
        missing_tools+=("sha256sum")
    fi
    
    # Check for secure file creation
    if ! command -v mktemp >/dev/null 2>&1; then
        missing_tools+=("mktemp")
    fi
    
    # Check for timeout command (for preventing hanging processes)
    if ! command -v timeout >/dev/null 2>&1; then
        missing_tools+=("timeout")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_warn "Missing security tools: ${missing_tools[*]}"
        log_warn "Some security features may not be available"
        return 1
    fi
    
    log_debug "All security prerequisites are available"
    return 0
}
