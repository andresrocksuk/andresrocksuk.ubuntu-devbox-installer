#!/bin/bash

# {{SOFTWARE_NAME}} installation script
# {{SOFTWARE_DESCRIPTION}}

set -e

# Source the installation framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$(cd "$SCRIPT_DIR/../../utils" && pwd)"

# Source utilities and framework
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
    source "$UTILS_DIR/security-helpers.sh"
else
    # Fallback: source individual utilities
    if [ -f "$UTILS_DIR/logger.sh" ]; then
        source "$UTILS_DIR/logger.sh"
    else
        # Minimal fallback logging functions
        log_info() { echo "[INFO] $1"; }
        log_error() { echo "[ERROR] $1" >&2; }
        log_success() { echo "[SUCCESS] $1"; }
        log_warn() { echo "[WARN] $1"; }
        log_debug() { 
            if [ "${LOG_LEVEL:-INFO}" = "DEBUG" ]; then
                echo "[DEBUG] $1" >&2
            fi
        }
    fi
fi

# Software-specific configuration
SOFTWARE_NAME="{{SOFTWARE_NAME}}"
SOFTWARE_DESCRIPTION="{{SOFTWARE_DESCRIPTION}}"
COMMAND_NAME="{{COMMAND_NAME:-$SOFTWARE_NAME}}"
VERSION_FLAG="{{VERSION_FLAG:---version}}"

# Initialize the installation script
if command -v initialize_script >/dev/null 2>&1; then
    initialize_script "$SOFTWARE_NAME" "$SOFTWARE_DESCRIPTION"
fi

# Check for standalone execution
if command -v handle_standalone_execution >/dev/null 2>&1; then
    handle_standalone_execution "$SOFTWARE_NAME"
else
    if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
        log_info "Running $SOFTWARE_NAME installation script in standalone mode"
    fi
fi

# Main installation function
install_{{SOFTWARE_NAME_LOWERCASE}}() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if already installed (using framework if available)
    if command -v check_already_installed >/dev/null 2>&1; then
        if check_already_installed "$COMMAND_NAME" "$VERSION_FLAG"; then
            if command -v log_installation_result >/dev/null 2>&1; then
                local current_version
                current_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
                log_installation_result "$SOFTWARE_NAME" "already_installed" "$current_version"
            fi
            return 0
        fi
    else
        # Fallback: manual check
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local current_version
            current_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_info "$SOFTWARE_NAME is already installed (version: $current_version)"
            return 0
        fi
    fi
    
    # TODO: Add software-specific installation logic here
    # Examples of what to implement:
    
    # For APT packages:
    # sudo apt-get update
    # sudo apt-get install -y {{PACKAGE_NAME}}
    
    # For binary downloads:
    # local download_url="{{DOWNLOAD_URL}}"
    # local temp_file
    # if command -v create_temp_file >/dev/null 2>&1; then
    #     temp_file=$(create_temp_file "{{SOFTWARE_NAME}}")
    # else
    #     temp_file="/tmp/{{SOFTWARE_NAME}}.$$"
    # fi
    # 
    # if command -v download_file >/dev/null 2>&1; then
    #     download_file "$download_url" "$temp_file"
    # else
    #     # Fallback download
    #     if command -v curl >/dev/null 2>&1; then
    #         curl -fsSL "$download_url" -o "$temp_file"
    #     elif command -v wget >/dev/null 2>&1; then
    #         wget -O "$temp_file" "$download_url"
    #     else
    #         log_error "Neither curl nor wget available for downloading"
    #         return 1
    #     fi
    # fi
    # 
    # # Make executable and install
    # chmod +x "$temp_file"
    # sudo mv "$temp_file" "/usr/local/bin/$COMMAND_NAME"
    
    # For repository-based installations:
    # sudo apt-get update
    # sudo apt-get install -y prerequisites
    # curl -fsSL {{GPG_KEY_URL}} | sudo gpg --dearmor -o {{KEYRING_PATH}}
    # echo "{{REPOSITORY_LINE}}" | sudo tee {{SOURCES_LIST_PATH}}
    # sudo apt-get update
    # sudo apt-get install -y {{PACKAGE_NAME}}
    
    # Placeholder implementation - replace with actual installation logic
    log_error "Installation logic not implemented for $SOFTWARE_NAME"
    log_error "Please replace this placeholder with actual installation commands"
    return 1
    
    # Verify installation (using framework if available)
    if command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "$COMMAND_NAME --help"; then
            local installed_version
            installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local installed_version
            installed_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_success "$SOFTWARE_NAME installed successfully (version: $installed_version)"
            
            # Test installation
            log_info "Testing $SOFTWARE_NAME installation..."
            if $COMMAND_NAME --help >/dev/null 2>&1; then
                log_success "$SOFTWARE_NAME test successful"
            else
                log_warn "$SOFTWARE_NAME test failed, but installation appears successful"
            fi
            
            return 0
        else
            log_error "$SOFTWARE_NAME installation verification failed"
            return 1
        fi
    fi
}

# Run installation
install_{{SOFTWARE_NAME_LOWERCASE}}

# Template replacement instructions:
# 1. Replace {{SOFTWARE_NAME}} with the actual software name (e.g., "docker", "nodejs")
# 2. Replace {{SOFTWARE_DESCRIPTION}} with a brief description (e.g., "Docker Engine", "Node.js LTS")
# 3. Replace {{COMMAND_NAME}} with the command name if different from software name (e.g., "node" for nodejs)
# 4. Replace {{VERSION_FLAG}} with the version flag if different from --version (e.g., "-v", "--version")
# 5. Replace {{SOFTWARE_NAME_LOWERCASE}} with lowercase version for function name
# 6. Implement the actual installation logic in the TODO section
# 7. Remove this comment block and the placeholder error messages
