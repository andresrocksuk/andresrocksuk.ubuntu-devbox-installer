#!/bin/bash

# package-manager.sh - Package manager utilities for WSL installation

# Source required utilities
# Handle being sourced from different directories
if [ -n "${BASH_SOURCE[0]}" ]; then
    PKG_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
    if [ "$PKG_SCRIPT_DIR" = "${BASH_SOURCE[0]}" ]; then
        PKG_SCRIPT_DIR="."
    fi
    PKG_SCRIPT_DIR="$(cd "$PKG_SCRIPT_DIR" && pwd)"
else
    PKG_SCRIPT_DIR="${0%/*}"
    if [ "$PKG_SCRIPT_DIR" = "$0" ]; then
        PKG_SCRIPT_DIR="."
    fi
    PKG_SCRIPT_DIR="$(cd "$PKG_SCRIPT_DIR" && pwd)"
fi
source "$PKG_SCRIPT_DIR/logger.sh"
source "$PKG_SCRIPT_DIR/version-checker.sh"

# Function to setup non-interactive environment for apt operations
setup_noninteractive_apt() {
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    export NEEDRESTART_SUSPEND=1
    export APT_LISTCHANGES_FRONTEND=none
    export DEBIAN_PRIORITY=critical
}

# Function to run apt-get update with proper settings
safe_apt_update() {
    setup_noninteractive_apt
    sudo -E apt-get update -qq < /dev/null
}

# Function to run apt-get install with proper settings
safe_apt_install() {
    setup_noninteractive_apt
    sudo -E apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" "$@" < /dev/null
}

# Function to update package lists
update_package_lists() {
    log_info "Updating package lists..."

    # Wait for apt/dpkg locks to be released, up to 1 minute
    local lock_files=(/var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock)
    local start_time=$(date +%s)
    local timeout=60
    local locked=false
    for lock_file in "${lock_files[@]}"; do
        if sudo fuser "$lock_file" >/dev/null 2>&1; then
            locked=true
        fi
    done
    if [ "$locked" = true ]; then
        log_info "Waiting for apt/dpkg lock(s) to be released (timeout: ${timeout}s)..."
        while :; do
            local any_locked=false
            for lock_file in "${lock_files[@]}"; do
                if sudo fuser "$lock_file" >/dev/null 2>&1; then
                    any_locked=true
                fi
            done
            if [ "$any_locked" = false ]; then
                break
            fi
            local now=$(date +%s)
            local elapsed=$((now - start_time))
            if [ $elapsed -ge $timeout ]; then
                log_error "Timeout waiting for apt/dpkg lock(s) after ${timeout}s. Listing lock holders:"
                for lock_file in "${lock_files[@]}"; do
                    if sudo fuser "$lock_file" >/dev/null 2>&1; then
                        log_warn "Lock file: $lock_file"
                        sudo fuser -v "$lock_file" 2>&1 | while read -r line; do log_warn "$line"; done
                        sudo lsof "$lock_file" 2>/dev/null | while read -r line; do log_warn "$line"; done
                        # Attempt to forcibly kill the process holding the lock
                        local pids=$(sudo fuser "$lock_file" 2>/dev/null)
                        for pid in $pids; do
                            log_error "Killing process $pid holding $lock_file"
                            sudo kill -9 $pid
                        done
                        # Remove the lock file if it still exists
                        if [ -f "$lock_file" ]; then
                            log_warn "Removing lock file: $lock_file"
                            sudo rm -f "$lock_file"
                        fi
                    fi
                done
                break
            fi
            sleep 2
        done
    fi

    if log_command "safe_apt_update"; then
        log_success "Package lists updated successfully"
        
        # Run upgrade if requested
        if [ "${RUN_APT_UPGRADE:-false}" = "true" ]; then
            log_info "Running apt-get upgrade as requested..."
            if log_command "sudo -E apt-get upgrade -y -qq"; then
                log_success "System packages upgraded successfully"
            else
                log_error "Failed to upgrade system packages"
                return 1
            fi
        fi
        
        return 0
    else
        log_error "Failed to update package lists"
        return 1
    fi
}

# Function to install apt packages
install_apt_package() {
    local package="$1"
    local version="$2"
    local force_install="${3:-false}"
    
    log_install_start "$package (apt)"
    
    # Check if already installed with correct version
    if [ "$force_install" != "true" ] && check_software_version "$package" "$version"; then
        log_install_skip "$package" "already installed with compatible version"
        return 0
    fi
    
    # Install package
    local install_cmd
    
    if [ "$version" != "latest" ]; then
        # Try to install specific version
        install_cmd="safe_apt_install $package=$version"
    else
        install_cmd="safe_apt_install $package"
    fi
    
    if log_command "$install_cmd"; then
        log_install_success "$package"
        return 0
    else
        log_install_failure "$package" "apt installation failed"
        return 1
    fi
}

# Function to install Python packages
install_python_package() {
    local package="$1"
    local version="$2"
    local force_install="${3:-false}"
    
    log_install_start "$package (pip system-wide)"
    
    # Check if Python is installed
    if ! command_exists "python3"; then
        log_install_failure "$package" "Python3 is not installed"
        return 1
    fi
    
    # Check if pip is installed
    if ! command_exists "pip3" && ! python3 -m pip --version >/dev/null 2>&1; then
        log_install_failure "$package" "pip is not installed"
        return 1
    fi
    
    # Check if already installed with correct version (system-wide)
    if [ "$force_install" != "true" ] && check_python_package_version "$package" "$version"; then
        log_install_skip "$package" "already installed with compatible version"
        return 0
    fi
    
    # Install package system-wide using sudo pip to bypass PEP 668 restrictions
    # This makes the package available to all users and avoids PATH issues
    local pip_cmd="sudo python3 -m pip install --break-system-packages"
    
    if [ "$version" != "latest" ]; then
        pip_cmd="$pip_cmd $package==$version"
    else
        pip_cmd="$pip_cmd $package"
    fi
    
    if log_command "$pip_cmd"; then
        log_install_success "$package"
        return 0
    else
        log_install_failure "$package" "pip system-wide installation failed"
        return 1
    fi
}

# Function to install PowerShell modules
install_powershell_module() {
    local module="$1"
    local version="$2"
    local force_install="${3:-false}"
    
    log_install_start "$module (PowerShell)"
    
    # Check if PowerShell is installed
    if ! command_exists "pwsh"; then
        log_install_failure "$module" "PowerShell is not installed"
        return 1
    fi
    
    # Check if already installed with correct version
    if [ "$force_install" != "true" ] && check_powershell_module_version "$module" "$version"; then
        log_install_skip "$module" "already installed with compatible version"
        return 0
    fi
    
    # Install module
    local install_cmd
    if [ "$version" != "latest" ]; then
        install_cmd="pwsh -Command \"Install-Module -Name '$module' -RequiredVersion '$version' -Force -AllowClobber -Scope AllUsers\""
    else
        install_cmd="pwsh -Command \"Install-Module -Name '$module' -Force -AllowClobber -Scope AllUsers\""
    fi
    
    if log_command "$install_cmd"; then
        log_install_success "$module"
        return 0
    else
        log_install_failure "$module" "PowerShell module installation failed"
        return 1
    fi
}

# Function to run custom installation script
run_custom_installation_script() {
    local software="$1"
    local script_path="$2"
    local force_install="${3:-false}"
    
    log_install_start "$software (custom script)"
    
    # Validate input parameters
    if [ -z "$software" ]; then
        log_install_failure "$software" "software name is required"
        return 1
    fi
    
    if [ -z "$script_path" ]; then
        log_install_failure "$software" "script path is required"
        return 1
    fi
    
    # Validate script path security
    if [[ "$script_path" =~ \.\./|\.\.\\ ]]; then
        log_install_failure "$software" "script path contains directory traversal: $script_path"
        return 1
    fi
    
    # Check if script exists
    if [ ! -f "$script_path" ]; then
        log_install_failure "$software" "installation script not found: $script_path"
        return 1
    fi
    
    # Check if script is readable
    if [ ! -r "$script_path" ]; then
        log_install_failure "$software" "installation script is not readable: $script_path"
        return 1
    fi
    
    # Validate script is a bash script
    if ! head -n 1 "$script_path" | grep -q "^#!/bin/bash"; then
        log_warn "Script does not start with #!/bin/bash shebang: $script_path"
    fi
    
    # Make script executable
    if ! chmod +x "$script_path"; then
        log_install_failure "$software" "failed to make script executable: $script_path"
        return 1
    fi
    
    # Log script execution context
    log_info "Executing installation script: $script_path"
    log_info "Force install: $force_install"
    
    # Set environment variables for the script
    export FORCE_INSTALL="$force_install"
    export INSTALLING_SOFTWARE="$software"
    export DEBIAN_FRONTEND=noninteractive
    
    # Run installation script with timeout and improved error handling
    local script_exit_code
    
    # Execute script without output redirection to prevent hanging
    # and redirect stdin from /dev/null to prevent prompts from hanging
    # Use shorter timeout to detect issues faster
    if timeout 600 bash "$script_path" < /dev/null; then
        script_exit_code=0
    else
        script_exit_code=$?
    fi
    
    # Clean up environment variables
    unset FORCE_INSTALL INSTALLING_SOFTWARE DEBIAN_FRONTEND
    
    # Enhanced error reporting based on exit code
    if [ $script_exit_code -eq 0 ]; then
        log_install_success "$software"
        return 0
    elif [ $script_exit_code -eq 124 ]; then
        log_install_failure "$software" "custom installation script timed out after 10 minutes"
        return 1
    else
        log_install_failure "$software" "custom installation script failed with exit code $script_exit_code"
        return 1
    fi
}

# Function to validate YAML dependencies are available
validate_yaml_dependencies() {
    if ! ensure_yq; then
        log_error "yq is required for YAML processing but could not be installed"
        return 1
    fi
    
    log_debug "YAML dependencies validated successfully"
    return 0
}

# Function to ensure yq is available for YAML parsing
ensure_yq() {
    if ! command_exists "yq"; then
        log_info "Installing yq for YAML parsing..."
        
        # Download and install yq
        local yq_version="v4.44.3"
        local yq_binary="yq_linux_amd64"
        local yq_url="https://github.com/mikefarah/yq/releases/download/${yq_version}/${yq_binary}"
        
        if command_exists "curl"; then
            curl -L "$yq_url" -o "/tmp/yq"
        elif command_exists "wget"; then
            wget "$yq_url" -O "/tmp/yq"
        else
            log_error "Neither curl nor wget available for downloading yq"
            return 1
        fi
        
        chmod +x "/tmp/yq"
        sudo mv "/tmp/yq" "/usr/local/bin/yq"
        
        if command_exists "yq"; then
            log_success "yq installed successfully"
            return 0
        else
            log_error "Failed to install yq"
            return 1
        fi
    else
        log_debug "yq is already available"
        return 0
    fi
}

# Function to check prerequisites
check_prerequisites() {
    local prerequisites=("$@")
    local missing_prerequisites=()
    
    log_info "Checking prerequisites..."
    
    for prereq in "${prerequisites[@]}"; do
        if ! command_exists "$prereq"; then
            missing_prerequisites+=("$prereq")
            log_warn "Missing prerequisite: $prereq"
        else
            log_debug "Prerequisite found: $prereq"
        fi
    done
    
    if [ ${#missing_prerequisites[@]} -eq 0 ]; then
        log_success "All prerequisites satisfied"
        return 0
    else
        log_error "Missing prerequisites: ${missing_prerequisites[*]}"
        return 1
    fi
}

# Function to install prerequisites
install_prerequisites() {
    local prerequisites=("$@")
    
    log_info "Installing prerequisites..."
    
    for prereq in "${prerequisites[@]}"; do
        case "$prereq" in
            "curl"|"wget"|"git"|"jq")
                install_apt_package "$prereq" "latest"
                ;;
            "python3")
                install_apt_package "python3" "latest"
                ;;
            "pip"|"pip3")
                install_apt_package "python3-pip" "latest"
                ;;
            "yq")
                ensure_yq
                ;;
            *)
                log_warn "Unknown prerequisite: $prereq"
                ;;
        esac
    done
}

# Function to clean up package cache
cleanup_package_cache() {
    log_info "Cleaning up package cache..."
    
    if log_command "sudo apt-get autoremove -y"; then
        log_debug "Autoremove completed"
    fi
    
    if log_command "sudo apt-get autoclean"; then
        log_debug "Autoclean completed"
    fi
    
    log_success "Package cache cleanup completed"
}

# Function to upgrade all packages
upgrade_all_packages() {
    log_info "Upgrading all packages..."
    
    if update_package_lists; then
        if log_command "sudo apt-get upgrade -y"; then
            log_success "All packages upgraded successfully"
            cleanup_package_cache
            return 0
        else
            log_error "Failed to upgrade packages"
            return 1
        fi
    else
        return 1
    fi
}

# Function to validate installation prerequisites
validate_installation_prerequisites() {
    local prerequisites=("$@")
    local missing_prereqs=()
    
    log_debug "Validating installation prerequisites: ${prerequisites[*]}"
    
    for prereq in "${prerequisites[@]}"; do
        # Validate prerequisite name
        if [[ ! "$prereq" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            log_error "Invalid prerequisite name: $prereq"
            return 1
        fi
        
        if ! command_exists "$prereq"; then
            missing_prereqs+=("$prereq")
        fi
    done
    
    if [ ${#missing_prereqs[@]} -gt 0 ]; then
        log_error "Missing prerequisites: ${missing_prereqs[*]}"
        return 1
    fi
    
    log_debug "All prerequisites are satisfied"
    return 0
}

# Function to sanitize version string
sanitize_version_string() {
    local version="$1"
    
    # Remove potentially dangerous characters, keep only version-related characters
    local sanitized
    sanitized=$(echo "$version" | tr -cd 'a-zA-Z0-9v._+-')
    
    # Limit length to prevent extremely long version strings
    if [ ${#sanitized} -gt 100 ]; then
        sanitized="${sanitized:0:100}"
        log_warn "Version string truncated to 100 characters"
    fi
    
    echo "$sanitized"
}

# Function to validate package installation parameters
validate_package_params() {
    local package_name="$1"
    local version="$2"
    
    # Validate package name
    if [ -z "$package_name" ]; then
        log_error "Package name cannot be empty"
        return 1
    fi
    
    if [ ${#package_name} -gt 200 ]; then
        log_error "Package name too long (max 200 characters)"
        return 1
    fi
    
    if [[ ! "$package_name" =~ ^[a-zA-Z0-9._+-]+$ ]]; then
        log_error "Invalid package name format: $package_name"
        return 1
    fi
    
    # Validate version if provided
    if [ -n "$version" ]; then
        local sanitized_version
        sanitized_version=$(sanitize_version_string "$version")
        
        if [ -z "$sanitized_version" ]; then
            log_error "Invalid version format: $version"
            return 1
        fi
    fi
    
    return 0
}