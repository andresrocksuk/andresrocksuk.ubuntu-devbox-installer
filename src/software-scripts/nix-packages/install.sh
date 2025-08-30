#!/bin/bash

# nix-packages installation script
# Installs Nix packages via flakes or individual packages

set -e

# Get script directory for utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/utils"
WSL_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Configuration
SOFTWARE_NAME="nix-packages"
SOFTWARE_DESCRIPTION="Nix packages via flakes"
FLAKE_FILE="$WSL_DIR/install.flake.nix"

# Source the installation framework if available
FRAMEWORK_AVAILABLE=false
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
    FRAMEWORK_AVAILABLE=true
fi

# Source utilities if available (fallback)
if [ -f "$UTILS_DIR/logger.sh" ]; then
    source "$UTILS_DIR/logger.sh"
else
    # Fallback logging functions
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warn() { echo "[WARN] $1"; }
fi

# Main installation function using framework patterns
install_nix_packages() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if Nix is available (prerequisite)
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_dependencies >/dev/null 2>&1; then
        if ! check_dependencies "nix"; then
            log_error "Nix is required but not available. Please install Nix first."
            return 1
        fi
    else
        # Fallback check
        if ! check_nix_available; then
            log_error "Nix is required but not available. Please install Nix first."
            return 1
        fi
    fi
    
    # Setup sudo access to Nix if needed
    setup_sudo_nix_access
    
    # Install from local flake
    if [ -f "$FLAKE_FILE" ]; then
        if install_local_flake "$FLAKE_FILE" "Default development environment"; then
            if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v log_installation_result >/dev/null 2>&1; then
                log_installation_result "$SOFTWARE_NAME" "success" "via flake"
            else
                log_success "$SOFTWARE_DESCRIPTION installed successfully via flake"
            fi
            show_nix_packages_usage_info
            return 0
        else
            if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v log_installation_result >/dev/null 2>&1; then
                log_installation_result "$SOFTWARE_NAME" "failure" "" "flake installation failed"
            else
                log_error "$SOFTWARE_DESCRIPTION installation failed"
            fi
            return 1
        fi
    else
        log_warn "No flake file found at $FLAKE_FILE"
        log_info "Skipping Nix packages installation"
        return 0
    fi
}

# Helper function to show usage information
show_nix_packages_usage_info() {
    log_info "Nix packages have been installed via flakes"
    log_info "To use the development environment:"
    log_info "  nix develop                # Enter development shell"
    log_info "  nix run <package>          # Run specific package"
    log_info "  nix shell <package>        # Temporary shell with package"
    log_info ""
    log_info "The packages are available system-wide and in your user environment"
}

# Function to check if Nix is available
check_nix_available() {
    if ! command -v nix >/dev/null 2>&1; then
        log_warn "Nix is not installed or not available in PATH"
        log_info "This is expected when running nix_packages section independently"
        return 1
    fi
    
    # Source Nix environment if needed
    if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        source "$HOME/.nix-profile/etc/profile.d/nix.sh"
    elif [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
        source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    fi
    
    return 0
}

# Function to run command with timeout (fallback if timeout command not available)
run_with_timeout() {
    local timeout_duration="$1"
    shift
    local command=("$@")
    
    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout_duration" "${command[@]}"
    else
        # Fallback: just run the command without timeout
        log_warn "timeout command not available, running without timeout"
        "${command[@]}"
    fi
}

# Function to ensure nix command is available with sudo
setup_sudo_nix_access() {
    log_info "Setting up sudo access to Nix commands..."
    
    # First check if we can use sudo at all
    if ! sudo -n true 2>/dev/null; then
        log_warn "No sudo access available, packages will be installed for current user only"
        return 0  # This is a warning condition, not a failure - continue execution
    fi
    
    # Check if sudo can access nix with a timeout
    if run_with_timeout 5 sudo nix --version >/dev/null 2>&1; then
        log_success "Sudo already has access to Nix"
        return 0
    fi
    
    # Try to fix sudo PATH for nix
    if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
        log_info "Ensuring Nix environment is available for sudo..."
        
        # Create a sudo wrapper script if needed
        if [ ! -f "/usr/local/bin/sudo-nix" ]; then
            sudo tee "/usr/local/bin/sudo-nix" > /dev/null << 'EOF'
#!/bin/bash
# Sudo wrapper for Nix commands with proper environment

# Source Nix environment
if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Execute nix command with sudo privileges
exec nix "$@"
EOF
            sudo chmod +x "/usr/local/bin/sudo-nix"
            log_info "Created sudo-nix wrapper"
        fi
    fi
    
    # Test sudo access again with timeout
    if run_with_timeout 5 sudo nix --version >/dev/null 2>&1; then
        log_success "Sudo access to Nix configured successfully"
        return 0
    else
        log_warn "Could not configure sudo access to Nix. System-wide installation may not work."
        return 1
    fi
}

# Function to install from a local flake
install_local_flake() {
    local flake_path="$1"
    local description="$2"
    
    log_info "Installing packages from local flake: $description"
    log_info "Flake file: $flake_path"
    
    # Resolve full path for the flake file (not directory)
    local full_path
    if [[ "$flake_path" = /* ]]; then
        full_path="$flake_path"
    else
        full_path="$WSL_DIR/$flake_path"
    fi
    
    if [ ! -f "$full_path" ]; then
        log_error "Flake file not found: $full_path"
        return 1
    fi
    
    log_info "Found flake file at: $full_path"
    
    # Create a temporary directory for the flake installation
    local temp_dir="/tmp/local-flake-$$"
    mkdir -p "$temp_dir"
    
    # Copy the flake file to the temporary directory as flake.nix
    if cp "$full_path" "$temp_dir/flake.nix"; then
        log_info "Flake file copied to temporary directory: $temp_dir/flake.nix"
    else
        log_error "Failed to copy flake file to temporary directory"
        rm -rf "$temp_dir"
        return 1
    fi
    
    local original_dir="$(pwd)"
    cd "$temp_dir"
    
    # Install packages
    local install_result=0
    if sudo -n true 2>/dev/null; then
        # Try to install with sudo for system-wide availability with timeout
        log_info "Attempting system-wide installation..."
        if run_with_timeout 30 sudo nix --extra-experimental-features "nix-command flakes" profile install . --priority 5 2>/dev/null; then
            log_success "Local flake packages installed system-wide successfully"
        else
            log_warn "System-wide installation failed or timed out, trying user installation..."
            if nix --extra-experimental-features "nix-command flakes" profile install . --priority 5; then
                log_success "Local flake packages installed for current user"
            else
                log_error "Failed to install local flake packages"
                install_result=1
            fi
        fi
    else
        # No sudo access, install for current user
        log_info "Installing local flake packages for current user..."
        if nix --extra-experimental-features "nix-command flakes" profile install . --priority 5; then
            log_success "Local flake packages installed for current user"
        else
            log_error "Failed to install local flake packages"
            install_result=1
        fi
    fi
    
    # Cleanup and return
    cd "$original_dir"
    rm -rf "$temp_dir"
    return $install_result
}

# Function to install from a remote flake
install_remote_flake() {
    local flake_url="$1"
    local description="$2"
    
    log_info "Installing packages from remote flake: $description"
    log_info "Flake URL: $flake_url"
    
    # Check if this is a direct file URL (contains raw or ends with .nix)
    if [[ "$flake_url" == *"raw"* ]] || [[ "$flake_url" == *".nix" ]]; then
        log_info "Detected direct flake file URL, downloading..."
        
        # Create temporary directory for the flake
        local temp_dir="/tmp/remote-flake-$$"
        mkdir -p "$temp_dir"
        local flake_file="$temp_dir/flake.nix"
        
        # Download the flake file
        if command -v curl >/dev/null 2>&1; then
            if curl -sL "$flake_url" -o "$flake_file"; then
                log_success "Flake file downloaded successfully"
            else
                log_error "Failed to download flake file with curl"
                rm -rf "$temp_dir"
                return 1
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q "$flake_url" -O "$flake_file"; then
                log_success "Flake file downloaded successfully"
            else
                log_error "Failed to download flake file with wget"
                rm -rf "$temp_dir"
                return 1
            fi
        else
            log_error "Neither curl nor wget available for downloading"
            rm -rf "$temp_dir"
            return 1
        fi
        
        # Verify the downloaded file exists and has content
        if [ ! -s "$flake_file" ]; then
            log_error "Downloaded flake file is empty or doesn't exist"
            rm -rf "$temp_dir"
            return 1
        fi
        
        log_info "Using downloaded flake file: $flake_file"
        
        # Change to temp directory and install
        local original_dir="$(pwd)"
        cd "$temp_dir"
        
        # Install packages
        local install_result=0
        if sudo -n true 2>/dev/null; then
            # Try to install with sudo for system-wide availability with timeout
            if run_with_timeout 30 sudo nix --extra-experimental-features "nix-command flakes" profile install . --priority 5 2>/dev/null; then
                log_success "Remote flake packages installed system-wide successfully"
            else
                log_warn "System-wide installation failed or timed out, trying user installation..."
                if nix --extra-experimental-features "nix-command flakes" profile install . --priority 5; then
                    log_success "Remote flake packages installed for current user"
                else
                    log_error "Failed to install remote flake packages"
                    install_result=1
                fi
            fi
        else
            # No sudo access, install for current user
            log_info "Installing remote flake packages for current user..."
            if nix --extra-experimental-features "nix-command flakes" profile install . --priority 5; then
                log_success "Remote flake packages installed for current user"
            else
                log_error "Failed to install remote flake packages"
                install_result=1
            fi
        fi
        
        # Cleanup and return
        cd "$original_dir"
        rm -rf "$temp_dir"
        return $install_result
        
    else
        # This is a Git repository URL, use standard Nix flake installation
        log_info "Using Git repository flake URL..."
        
        # Install packages system-wide using sudo
        log_info "Installing remote flake packages system-wide..."
        
        if sudo -n true 2>/dev/null; then
            # Try to install with sudo for system-wide availability with timeout
            if run_with_timeout 30 sudo nix --extra-experimental-features "nix-command flakes" profile install "$flake_url" --priority 5 2>/dev/null; then
                log_success "Remote flake packages installed system-wide successfully"
            else
                log_warn "System-wide installation failed or timed out, trying user installation..."
                if nix --extra-experimental-features "nix-command flakes" profile install "$flake_url" --priority 5; then
                    log_success "Remote flake packages installed for current user"
                else
                    log_error "Failed to install remote flake packages"
                    return 1
                fi
            fi
        else
            # No sudo access, install for current user
            log_info "Installing remote flake packages for current user..."
            if nix --extra-experimental-features "nix-command flakes" profile install "$flake_url" --priority 5; then
                log_success "Remote flake packages installed for current user"
            else
                log_error "Failed to install remote flake packages"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Function to install individual packages
install_individual_packages() {
    local packages=("$@")
    local failed_packages=()
    
    log_info "Installing individual Nix packages..."
    
    for package_spec in "${packages[@]}"; do
        # Parse package specification (format: name:package:description)
        IFS=':' read -r name package description <<< "$package_spec"
        
        log_info "Installing $name ($package)..."
        
        # Check if already installed
        if command -v "$name" >/dev/null 2>&1; then
            log_info "$name is already available, skipping"
            continue
        fi
        
        # Convert nixpkgs.package format to nixpkgs#package format for flakes
        if [[ "$package" == nixpkgs.* ]]; then
            package="${package/nixpkgs./nixpkgs#}"
            log_info "Converted package reference to: $package"
        fi
        
        # Install package system-wide using sudo
        local install_success=false
        if sudo -n true 2>/dev/null; then
            # Try to install with sudo for system-wide availability with timeout
            if run_with_timeout 30 sudo nix --extra-experimental-features "nix-command flakes" profile install "$package" --priority 5 2>/dev/null; then
                log_success "$name installed system-wide successfully"
                install_success=true
            else
                log_warn "System-wide installation of $name failed or timed out, trying user installation..."
                if nix --extra-experimental-features "nix-command flakes" profile install "$package" --priority 5; then
                    log_success "$name installed for current user"
                    install_success=true
                else
                    log_error "Failed to install $name"
                    failed_packages+=("$name")
                fi
            fi
        else
            # No sudo access, install for current user
            log_info "Installing $name for current user..."
            if nix --extra-experimental-features "nix-command flakes" profile install "$package" --priority 5; then
                log_success "$name installed for current user"
                install_success=true
            else
                log_error "Failed to install $name"
                failed_packages+=("$name")
            fi
        fi
    done
    
    # Report failed packages
    if [ ${#failed_packages[@]} -gt 0 ]; then
        log_error "Failed to install the following packages: ${failed_packages[*]}"
        return 1
    fi
    
    return 0
}

# Function to read nix packages configuration from install.yaml
read_nix_config() {
    local config_file="$WSL_DIR/install.yaml"
    
    if [ ! -f "$config_file" ]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Check if yq is available
    if ! command -v yq >/dev/null 2>&1; then
        log_error "yq is required but not available"
        return 1
    fi
    
    log_info "Reading Nix packages configuration from $config_file"
    
    # Check if nix_packages section exists
    local nix_packages_count
    nix_packages_count=$(yq eval '.nix_packages | length' "$config_file" 2>/dev/null)
    
    if [ "$nix_packages_count" = "0" ] || [ "$nix_packages_count" = "null" ]; then
        log_info "No nix_packages configuration found"
        return 0
    fi
    
    log_info "Found $nix_packages_count nix package configuration(s)"
    
    # Process each configuration
    for i in $(seq 0 $((nix_packages_count - 1))); do
        # Check if this is a flake configuration
        local has_flake
        has_flake=$(yq eval ".nix_packages[$i] | has(\"flake\")" "$config_file" 2>/dev/null)
        
        if [ "$has_flake" = "true" ]; then
            local enabled
            enabled=$(yq eval ".nix_packages[$i].flake.enabled // false" "$config_file")
            
            if [ "$enabled" = "true" ]; then
                local flake_type
                flake_type=$(yq eval ".nix_packages[$i].flake.type" "$config_file")
                local description
                description=$(yq eval ".nix_packages[$i].flake.description // \"Nix flake\"" "$config_file")
                
                if [ "$flake_type" = "local" ]; then
                    local path
                    path=$(yq eval ".nix_packages[$i].flake.path" "$config_file")
                    install_local_flake "$path" "$description"
                elif [ "$flake_type" = "remote" ]; then
                    local url
                    url=$(yq eval ".nix_packages[$i].flake.url" "$config_file")
                    install_remote_flake "$url" "$description"
                else
                    log_error "Unknown flake type: $flake_type"
                fi
            else
                log_info "Flake configuration is disabled, skipping"
            fi
        fi
        
        # Check if this is a packages configuration
        local has_packages
        has_packages=$(yq eval ".nix_packages[$i] | has(\"packages\")" "$config_file" 2>/dev/null)
        
        if [ "$has_packages" = "true" ]; then
            local enabled
            enabled=$(yq eval ".nix_packages[$i].packages.enabled // false" "$config_file")
            
            if [ "$enabled" = "true" ]; then
                local packages_count
                packages_count=$(yq eval ".nix_packages[$i].packages.list | length" "$config_file" 2>/dev/null)
                
                if [ "$packages_count" -gt 0 ]; then
                    log_info "Found $packages_count individual packages to install"
                    
                    local packages_list=()
                    for j in $(seq 0 $((packages_count - 1))); do
                        local name
                        name=$(yq eval ".nix_packages[$i].packages.list[$j].name" "$config_file")
                        local package
                        package=$(yq eval ".nix_packages[$i].packages.list[$j].package" "$config_file")
                        local description
                        description=$(yq eval ".nix_packages[$i].packages.list[$j].description // \"\"" "$config_file")
                        
                        packages_list+=("$name:$package:$description")
                    done
                    
                    if ! install_individual_packages "${packages_list[@]}"; then
                        log_error "Individual package installation failed"
                        return 1
                    fi
                fi
            else
                log_info "Individual packages configuration is disabled, skipping"
            fi
        fi
    done
}

# Function to verify installations
verify_installations() {
    log_info "Verifying Nix package installations..."
    
    # List installed packages
    log_info "Currently installed Nix packages:"
    if nix --extra-experimental-features "nix-command flakes" profile list 2>/dev/null; then
        log_success "Nix packages listed successfully"
    else
        log_warn "Could not list Nix packages"
    fi
    
    # Test a few common commands if they were installed
    local test_commands=("hello" "figlet")
    
    for cmd in "${test_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_success "$cmd is available"
            
            # Test the command
            case "$cmd" in
                "hello")
                    if "$cmd" >/dev/null 2>&1; then
                        log_success "$cmd executed successfully"
                    fi
                    ;;
                "figlet")
                    if echo "Test" | "$cmd" >/dev/null 2>&1; then
                        log_success "$cmd executed successfully"
                    fi
                    ;;
            esac
        fi
    done
}

# Main installation function
install_nix_packages() {
    log_info "Starting Nix packages installation..."
    
    # Check if Nix is available
    if ! check_nix_available; then
        log_warn "Nix is not available. Attempting to install Nix first..."
        
        # Try to install Nix using the existing installation script
        local nix_script="$(dirname "$SCRIPT_DIR")/nix/install.sh"
        
        if [ -f "$nix_script" ]; then
            log_info "Found Nix installation script at: $nix_script"
            log_info "Running Nix installation..."
            
            if bash "$nix_script"; then
                log_success "Nix installation completed"
                
                # Source Nix environment
                if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
                elif [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
                    source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
                fi
                
                # Verify Nix is now available
                if ! command -v nix >/dev/null 2>&1; then
                    log_error "Nix installation completed but command is still not available"
                    log_info "You may need to restart your shell or source the Nix profile manually"
                    return 1
                fi
                
                log_success "Nix is now available"
            else
                log_error "Failed to install Nix automatically"
                log_info "Please install Nix manually before running this script"
                return 1
            fi
        else
            log_error "Nix installation script not found at: $nix_script"
            log_info "Please install Nix manually before running this script"
            return 1
        fi
    else
        log_success "Nix is already available"
    fi
    
    # Setup sudo access if possible
    setup_sudo_nix_access
    
    # Read and process configuration
    if ! read_nix_config; then
        log_error "Failed to read Nix packages configuration"
        return 1
    fi
    
    # Verify installations
    verify_installations
    
    log_success "Nix packages installation completed!"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if install_nix_packages; then
        log_info "Nix packages installation completed successfully"
        exit 0
    else
        log_error "Nix packages installation failed"
        exit 1
    fi
fi
