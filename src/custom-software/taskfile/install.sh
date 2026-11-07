#!/bin/bash

# taskfile installation script
# Installs Task (Taskfile task runner / build tool) from official sources

set -e

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$(cd "$SCRIPT_DIR/../../utils" && pwd)"

# Initialize framework availability
FRAMEWORK_AVAILABLE=false

# Try to source the installation framework and security helpers
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
    FRAMEWORK_AVAILABLE=true
fi

if [ -f "$UTILS_DIR/security-helpers.sh" ]; then
    source "$UTILS_DIR/security-helpers.sh"
fi

if [ -f "$UTILS_DIR/package-manager.sh" ]; then
    source "$UTILS_DIR/package-manager.sh"
fi

# Fallback: source logger directly if framework is unavailable
if [ "$FRAMEWORK_AVAILABLE" = "false" ]; then
    if [ -f "$UTILS_DIR/logger.sh" ]; then
        source "$UTILS_DIR/logger.sh"
    else
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
SOFTWARE_NAME="taskfile"
SOFTWARE_DESCRIPTION="Task (Taskfile task runner / build tool)"
COMMAND_NAME="task"
VERSION_FLAG="--version"
GITHUB_REPO="go-task/task"
OFFICIAL_INSTALLER_URL="https://taskfile.dev/install.sh"

# Initialize the installation script if framework is available
if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v initialize_script >/dev/null 2>&1; then
    initialize_script "$SOFTWARE_NAME" "$SOFTWARE_DESCRIPTION" || FRAMEWORK_AVAILABLE=false
fi

# Check for standalone execution
if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v handle_standalone_execution >/dev/null 2>&1; then
    if handle_standalone_execution "$SOFTWARE_NAME"; then
        log_info "Running in standalone mode with framework"
    fi
else
    if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
        log_info "Running $SOFTWARE_NAME installation script in standalone mode"
    fi
fi

# Function to configure shell completion
setup_task_completion() {
    if ! command -v "$COMMAND_NAME" >/dev/null 2>&1; then
        return 0
    fi

    # Setup Bash completion if target directory exists
    if [ -d "/etc/bash_completion.d" ]; then
        log_info "Configuring Task bash autocompletion..."
        if "$COMMAND_NAME" --completion bash 2>/dev/null | sudo tee "/etc/bash_completion.d/task" >/dev/null 2>&1; then
            log_debug "Task bash completion configured successfully"
        else
            log_warn "Failed to configure Task bash completion"
        fi
    fi

    # Setup Zsh completion if directory exists or can be created
    local zsh_completion_dir="/usr/local/share/zsh/site-functions"
    if [ -d "$zsh_completion_dir" ] || sudo mkdir -p "$zsh_completion_dir" 2>/dev/null; then
        log_info "Configuring Task zsh autocompletion..."
        if "$COMMAND_NAME" --completion zsh 2>/dev/null | sudo tee "$zsh_completion_dir/_task" >/dev/null 2>&1; then
            log_debug "Task zsh completion configured successfully"
        else
            log_warn "Failed to configure Task zsh completion"
        fi
    fi
}

# Helper function to display usage information
show_task_usage_info() {
    log_info "To get started with Task:"
    log_info "  task --init       # Initialize a new Taskfile.yml"
    log_info "  task --list       # List available tasks"
    log_info "  task <task-name>  # Run a specific task"
    log_info "  task --version    # Check Task version"
    log_info "  task --help       # Display help and options"
    log_info ""
    log_info "Documentation: https://taskfile.dev/"
}

# Main installation function
install_taskfile() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."

    # Ensure non-interactive environment is set up safely
    if command -v setup_noninteractive_apt >/dev/null 2>&1; then
        setup_noninteractive_apt
    fi

    # Check if already installed
    if [ "${FORCE_INSTALL:-false}" != "true" ]; then
        if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_already_installed >/dev/null 2>&1; then
            if check_already_installed "$COMMAND_NAME" "$VERSION_FLAG"; then
                if command -v log_installation_result >/dev/null 2>&1; then
                    local current_version
                    current_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
                    log_installation_result "$SOFTWARE_NAME" "already_installed" "$current_version"
                fi
                return 0
            fi
        else
            if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
                local current_version
                current_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' || echo "unknown")
                log_info "$SOFTWARE_NAME is already installed (version: $current_version)"
                return 0
            fi
        fi
    fi

    # Detect system architecture
    local arch
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v get_system_architecture >/dev/null 2>&1; then
        arch=$(get_system_architecture)
    else
        local machine
        machine=$(uname -m)
        case "$machine" in
            x86_64) arch="amd64" ;;
            aarch64|arm64) arch="arm64" ;;
            armv6l|armv7l) arch="arm" ;;
            i386|i686) arch="386" ;;
            *)
                log_error "Unsupported architecture: $machine"
                return 1
                ;;
        esac
    fi

    # Create secure temporary directory
    local temp_dir
    if command -v create_secure_temp_dir >/dev/null 2>&1; then
        temp_dir=$(create_secure_temp_dir "taskfile")
    else
        temp_dir=$(mktemp -d "/tmp/taskfile.XXXXXX")
        chmod 700 "$temp_dir"
    fi

    local install_successful=false

    # Approach 1: Official Task installation script (taskfile.dev/install.sh)
    # The official installer handles OS/architecture detection and SHA-256 checksum verification.
    log_info "Attempting installation using the official Task install script..."
    local installer_script="$temp_dir/install.sh"
    local download_ok=false

    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$OFFICIAL_INSTALLER_URL" -o "$installer_script" 2>/dev/null; then
            download_ok=true
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -qO "$installer_script" "$OFFICIAL_INSTALLER_URL" 2>/dev/null; then
            download_ok=true
        fi
    fi

    if [ "$download_ok" = "true" ] && [ -s "$installer_script" ]; then
        log_info "Executing official Task installer into secure temporary directory..."
        if sh "$installer_script" -d -b "$temp_dir" >/dev/null 2>&1 && [ -x "$temp_dir/$COMMAND_NAME" ]; then
            install_successful=true
            log_success "Task binary downloaded and verified by official installer"
        else
            log_warn "Official Task install script execution did not succeed; trying direct GitHub release fallback..."
        fi
    else
        log_warn "Could not fetch official installer script; trying direct GitHub release fallback..."
    fi

    # Approach 2: Direct GitHub release download fallback
    if [ "$install_successful" != "true" ]; then
        log_info "Attempting direct download from GitHub releases ($GITHUB_REPO)..."
        local api_url="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
        local release_info=""

        if command -v curl >/dev/null 2>&1; then
            release_info=$(curl -s "$api_url" 2>/dev/null || true)
        elif command -v wget >/dev/null 2>&1; then
            release_info=$(wget -qO- "$api_url" 2>/dev/null || true)
        fi

        local tag_name=""
        local download_url=""
        if [ -n "$release_info" ]; then
            tag_name=$(echo "$release_info" | grep '"tag_name":' | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')
            download_url=$(echo "$release_info" | grep '"browser_download_url":' | grep "task_linux_${arch}\.tar\.gz\"" | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')
        fi

        # Fallback to known stable version if API lookup was unavailable or rate-limited
        if [ -z "$download_url" ]; then
            tag_name="${tag_name:-v3.54.0}"
            download_url="https://github.com/$GITHUB_REPO/releases/download/${tag_name}/task_linux_${arch}.tar.gz"
        fi

        log_info "Downloading Task archive from: $download_url"
        local archive_file="$temp_dir/task.tar.gz"

        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$download_url" -o "$archive_file" 2>/dev/null || true
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$archive_file" "$download_url" 2>/dev/null || true
        fi

        if [ -s "$archive_file" ]; then
            if tar -xzf "$archive_file" -C "$temp_dir" 2>/dev/null && [ -x "$temp_dir/$COMMAND_NAME" ]; then
                install_successful=true
                log_success "Task binary extracted from GitHub release archive"
            fi
        fi
    fi

    # Validate that we have the binary
    if [ "$install_successful" != "true" ] || [ ! -x "$temp_dir/$COMMAND_NAME" ]; then
        log_error "Failed to acquire task binary"
        rm -rf "$temp_dir"
        if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v log_installation_result >/dev/null 2>&1; then
            log_installation_result "$SOFTWARE_NAME" "failure" "" "download or extraction failed"
        fi
        return 1
    fi

    # Install binary to /usr/local/bin
    log_info "Installing $COMMAND_NAME to /usr/local/bin..."
    if ! sudo mv "$temp_dir/$COMMAND_NAME" "/usr/local/bin/$COMMAND_NAME"; then
        log_error "Failed to move $COMMAND_NAME to /usr/local/bin"
        rm -rf "$temp_dir"
        return 1
    fi

    sudo chmod 755 "/usr/local/bin/$COMMAND_NAME"

    # Cleanup temporary files
    rm -rf "$temp_dir"

    # Verify installation
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "$COMMAND_NAME --help" "Usage:"; then
            local installed_version
            installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            setup_task_completion
            show_task_usage_info
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local installed_version
            installed_version=$($COMMAND_NAME $VERSION_FLAG 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' || echo "unknown")
            log_success "$SOFTWARE_DESCRIPTION installed successfully (version: $installed_version)"
            setup_task_completion
            show_task_usage_info
            return 0
        else
            log_error "$SOFTWARE_DESCRIPTION installation verification failed"
            return 1
        fi
    fi
}

# Run installation if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    install_taskfile "$@"
fi
