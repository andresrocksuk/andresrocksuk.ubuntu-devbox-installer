#!/bin/bash

# nix installation script
# Installs Nix package manager with multi-user and single-user support

set -e

# Get script directory for utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/utils"

# Configuration
SOFTWARE_NAME="nix"
SOFTWARE_DESCRIPTION="Nix package manager"
COMMAND_NAME="nix"
VERSION_FLAG="--version"
INSTALLER_URL="https://nixos.org/nix/install"

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

# Source environment setup utilities
if [ -f "$UTILS_DIR/environment-setup.sh" ]; then
    source "$UTILS_DIR/environment-setup.sh"
fi

install_nix() {
    log_info "Installing $SOFTWARE_DESCRIPTION..."
    
    # Check if already installed (using framework if available)
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_already_installed >/dev/null 2>&1; then
        if check_already_installed "$COMMAND_NAME" "$VERSION_FLAG"; then
            configure_nix_experimental_features
            return 0
        fi
    else
        # Fallback: manual check
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local current_version=$(nix --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_info "$SOFTWARE_DESCRIPTION is already installed (version: $current_version)"
            configure_nix_experimental_features
            return 0
        fi
    fi
    
    # Check if running as root - Nix installation as root has different requirements
    if [ "$EUID" -eq 0 ]; then
        install_nix_multiuser_as_root
    else
        install_nix_singleuser_as_user
    fi
    
    # Configure environment and experimental features
    setup_nix_environment
    configure_nix_experimental_features
    
    # Verify installation using framework if available
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v verify_installation >/dev/null 2>&1; then
        if verify_installation "$COMMAND_NAME" "$COMMAND_NAME --version" "nix"; then
            local installed_version=$(get_command_version "$COMMAND_NAME" "$VERSION_FLAG" 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_installation_result "$SOFTWARE_NAME" "success" "$installed_version"
            show_nix_usage_info
            return 0
        else
            log_installation_result "$SOFTWARE_NAME" "failure" "" "verification failed"
            return 1
        fi
    else
        # Fallback verification
        if command -v "$COMMAND_NAME" >/dev/null 2>&1; then
            local installed_version=$(nix --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            log_success "$SOFTWARE_DESCRIPTION installed successfully (version: $installed_version)"
            show_nix_usage_info
            return 0
        else
            log_error "$SOFTWARE_DESCRIPTION installation verification failed"
            return 1
        fi
    fi
}

# Helper function to install Nix in multi-user mode as root
install_nix_multiuser_as_root() {
    log_info "Running as root, using multi-user Nix installation method..."
    
    # Clean up any existing nixbld group/users that might conflict
    cleanup_existing_nix_users
    
    # Download and run installer
    local temp_installer="/tmp/nix-installer.sh"
    if ! download_nix_installer "$temp_installer"; then
        return 1
    fi
    
    # Install Nix in multi-user mode
    log_info "Installing Nix (multi-user mode)..."
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v safely_execute >/dev/null 2>&1; then
        if ! safely_execute "sh '$temp_installer' --daemon --yes" "Failed to install Nix in multi-user mode"; then
            rm -f "$temp_installer"
            return 1
        fi
    else
        # Fallback execution
        if ! sh "$temp_installer" --daemon --yes; then
            log_error "Failed to install Nix in multi-user mode"
            rm -f "$temp_installer"
            return 1
        fi
    fi
    
    # Clean up installer
    rm -f "$temp_installer"
    
    # Source Nix environment for multi-user installation
    if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
        log_info "Sourcing Nix daemon environment..."
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
}

# Helper function to install Nix in single-user mode as regular user
install_nix_singleuser_as_user() {
    log_info "Installing Nix in single-user mode..."
    
    # Check if /nix directory already exists and fix permissions if needed
    if [ -d "/nix" ]; then
        log_info "Nix directory already exists, checking installation..."
        
        # Check if the directory is writable, if not, fix permissions
        if [ ! -w "/nix" ]; then
            log_info "Fixing /nix directory permissions..."
            sudo chown -R "$USER" /nix
        fi
        
        if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
            log_info "Sourcing existing Nix environment..."
            source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi
    fi
    
    # Download and run installer
    local temp_installer="/tmp/nix-installer.sh"
    if ! download_nix_installer "$temp_installer"; then
        return 1
    fi
    
    # Install Nix in single-user mode for non-root
    log_info "Installing Nix (single-user mode)..."
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v safely_execute >/dev/null 2>&1; then
        if ! safely_execute "sh '$temp_installer' --no-daemon" "Failed to install Nix in single-user mode"; then
            rm -f "$temp_installer"
            return 1
        fi
    else
        # Fallback execution
        if ! sh "$temp_installer" --no-daemon; then
            log_error "Failed to install Nix in single-user mode"
            rm -f "$temp_installer"
            return 1
        fi
    fi
    
    # Clean up installer
    rm -f "$temp_installer"
    
    # Source Nix environment
    if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        log_info "Sourcing Nix environment..."
        source "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
}

# Helper function to download Nix installer
download_nix_installer() {
    local temp_installer="$1"
    
    log_info "Downloading Nix installer..."
    
    # Check dependencies and download
    if [ "$FRAMEWORK_AVAILABLE" = "true" ] && command -v check_dependencies >/dev/null 2>&1; then
        if ! check_dependencies "curl wget"; then
            return 1
        fi
        
        if command -v curl >/dev/null 2>&1; then
            if ! safely_execute "curl -L '$INSTALLER_URL' -o '$temp_installer'" "Failed to download Nix installer with curl"; then
                return 1
            fi
        elif command -v wget >/dev/null 2>&1; then
            if ! safely_execute "wget -O '$temp_installer' '$INSTALLER_URL'" "Failed to download Nix installer with wget"; then
                return 1
            fi
        fi
    else
        # Fallback download
        if command -v curl >/dev/null 2>&1; then
            curl -L "$INSTALLER_URL" -o "$temp_installer" || {
                log_error "Failed to download Nix installer with curl"
                return 1
            }
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$temp_installer" "$INSTALLER_URL" || {
                log_error "Failed to download Nix installer with wget"
                return 1
            }
        else
            log_error "Neither curl nor wget available for downloading"
            return 1
        fi
    fi
    
    # Make installer executable
    chmod +x "$temp_installer"
    return 0
}

# Helper function to cleanup existing nix build users
cleanup_existing_nix_users() {
    log_info "Cleaning up any existing Nix build users..."
    for i in $(seq 1 32); do
        if id "nixbld$i" >/dev/null 2>&1; then
            sudo userdel "nixbld$i" 2>/dev/null || true
        fi
    done
    
    if getent group nixbld >/dev/null 2>&1; then
        sudo groupdel nixbld 2>/dev/null || true
    fi
}

# Helper function to setup Nix environment
setup_nix_environment() {
    # Determine the correct Nix profile script
    local nix_profile_script=""
    if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        nix_profile_script="$HOME/.nix-profile/etc/profile.d/nix.sh"
    elif [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
        nix_profile_script="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    fi
    
    if [ -n "$nix_profile_script" ]; then
        log_info "Setting up Nix environment for all users..."
        
        # Always setup system-wide environment regardless of utility availability
        if sudo -n true 2>/dev/null; then
            create_systemwide_nix_environment "$nix_profile_script"
            setup_nix_skeleton_files "$nix_profile_script"
            create_nix_command_wrappers "$nix_profile_script"
        else
            log_warn "Cannot setup system-wide environment (no sudo access)"
        fi
        
        # Use environment setup utility if available for user environment
        if command -v add_to_path >/dev/null 2>&1; then
            # Add Nix to PATH
            if [ -d "/nix/var/nix/profiles/default/bin" ]; then
                add_to_path "/nix/var/nix/profiles/default/bin" "Nix package manager binaries"
            elif [ -d "$HOME/.nix-profile/bin" ]; then
                add_to_path "$HOME/.nix-profile/bin" "Nix package manager binaries"
            fi
        else
            # Fallback environment setup
            setup_nix_environment_fallback "$nix_profile_script"
        fi
    else
        log_warn "Could not find Nix profile script for environment setup"
    fi
}

# Helper function to create system-wide Nix environment
create_systemwide_nix_environment() {
    local nix_profile_script="$1"
    
    log_info "Creating system-wide Nix environment configuration..."
    
    # Add to system profile
    local system_profile="/etc/profile.d/nix.sh"
    if [ ! -f "$system_profile" ]; then
        sudo tee "$system_profile" > /dev/null << EOF
#!/bin/bash
# Nix package manager environment setup
if [ -f "$nix_profile_script" ]; then
    source "$nix_profile_script"
fi
EOF
        sudo chmod +x "$system_profile"
        log_info "Created system profile: $system_profile"
    fi
}

# Helper function to create Nix command wrappers
create_nix_command_wrappers() {
    local nix_profile_script="$1"
    
    # Create system-wide nix wrapper if needed
    if [ ! -f "/usr/local/bin/nix" ] && [ -f "/nix/var/nix/profiles/default/bin/nix" ]; then
        sudo mkdir -p /usr/local/bin
        sudo tee "/usr/local/bin/nix" > /dev/null << EOF
#!/bin/bash
# System-wide Nix wrapper script
if [ -f "$nix_profile_script" ]; then
    source "$nix_profile_script"
fi
exec /nix/var/nix/profiles/default/bin/nix "\$@"
EOF
        sudo chmod +x "/usr/local/bin/nix"
        log_info "Created system-wide nix wrapper: /usr/local/bin/nix"
        
        # Create wrappers for other common Nix commands
        for cmd in nix-env nix-channel nix-store nix-build nix-shell; do
            if [ -f "/nix/var/nix/profiles/default/bin/$cmd" ]; then
                log_info "Creating wrapper for $cmd..."
                sudo tee "/usr/local/bin/$cmd" > /dev/null << EOF
#!/bin/bash
# System-wide $cmd wrapper script
if [ -f "$nix_profile_script" ]; then
    source "$nix_profile_script"
fi
exec /nix/var/nix/profiles/default/bin/$cmd "\$@"
EOF
                sudo chmod +x "/usr/local/bin/$cmd"
            fi
        done
    fi
}

# Function to setup skeleton files for new users
setup_nix_skeleton_files() {
    local nix_profile_script="$1"
    
    log_info "Setting up Nix configuration for new users..."
    
    # Update skeleton files using environment setup utilities if available
    if command -v update_skeleton_files >/dev/null 2>&1; then
        # Use the standard environment setup approach for bash/profile
        local nix_config="[ -f \"$nix_profile_script\" ] && source \"$nix_profile_script\""
        update_skeleton_files "$nix_config" "Nix package manager environment"
        
        # Create separate Nix configuration for zsh integration
        create_nix_zsh_integration "$nix_profile_script"
    else
        # Use fallback method for bash/profile only (avoid zsh conflicts)
        setup_nix_skeleton_files_fallback "$nix_profile_script"
    fi
}

# Create separate Nix configuration for zsh integration
create_nix_zsh_integration() {
    local nix_profile_script="$1"
    
    log_info "Creating Nix zsh integration configuration"
    
    # Create a configuration snippet that can be sourced by zsh configurations
    local nix_config_dir="/usr/local/share/nix"
    local nix_config_file="$nix_config_dir/nix.zsh"
    
    if sudo -n true 2>/dev/null; then
        sudo mkdir -p "$nix_config_dir"
        sudo tee "$nix_config_file" > /dev/null << EOF
# Nix package manager environment
[ -f "$nix_profile_script" ] && source "$nix_profile_script"
EOF
        sudo chmod 644 "$nix_config_file"
        log_info "Created Nix configuration at $nix_config_file"
        log_info "This will be automatically loaded by the zsh configuration system"
    else
        log_warn "Cannot create system-wide Nix configuration (no sudo access)"
    fi
}

# Fallback function for setting up skeleton files
setup_nix_skeleton_files_fallback() {
    local nix_profile_script="$1"
    
    log_info "Updating skeleton files for new users (fallback method)..."
    
    # Ensure skel directory exists
    sudo mkdir -p /etc/skel
    
    # Only update bash/profile files to avoid conflicts with zsh setup
    local skel_files=("/etc/skel/.bashrc" "/etc/skel/.profile")
    
    for skel_file in "${skel_files[@]}"; do
        # Create the skeleton file if it doesn't exist
        if [ ! -f "$skel_file" ]; then
            sudo touch "$skel_file"
            log_info "Created $skel_file"
        fi
        
        # Check if Nix configuration already exists
        if ! sudo grep -q "nix.*profile" "$skel_file" 2>/dev/null; then
            echo "" | sudo tee -a "$skel_file" > /dev/null
            echo "# Nix package manager environment" | sudo tee -a "$skel_file" > /dev/null
            echo "[ -f \"$nix_profile_script\" ] && source \"$nix_profile_script\"" | sudo tee -a "$skel_file" > /dev/null
            log_info "Updated $skel_file with Nix configuration"
        else
            log_info "Nix configuration already exists in $skel_file"
        fi
    done
    
    # For zsh skeleton, create separate configuration instead of direct modification
    create_nix_zsh_integration "$nix_profile_script"
}

# Fallback function for setting up Nix environment
setup_nix_environment_fallback() {
    local nix_profile_script="$1"
    
    log_info "Using fallback environment setup for Nix"
    
    # Add to bashrc
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "nix.*profile" "$HOME/.bashrc"; then
            echo "" >> "$HOME/.bashrc"
            echo "# Nix package manager environment" >> "$HOME/.bashrc"
            echo "[ -f \"$nix_profile_script\" ] && source \"$nix_profile_script\"" >> "$HOME/.bashrc"
            log_info "Added Nix to ~/.bashrc"
        fi
    fi
    
    # Add to zshrc if it exists
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "nix.*profile" "$HOME/.zshrc"; then
            echo "" >> "$HOME/.zshrc"
            echo "# Nix package manager environment" >> "$HOME/.zshrc"
            echo "[ -f \"$nix_profile_script\" ] && source \"$nix_profile_script\"" >> "$HOME/.zshrc"
            log_info "Added Nix to ~/.zshrc"
        fi
    fi
    
    # Try to update skeleton files manually if we have sudo access
    if sudo -n true 2>/dev/null; then
        setup_nix_skeleton_files "$nix_profile_script"
    else
        log_warn "Cannot update skeleton files (no sudo access)"
    fi
}

# Function to configure Nix experimental features
configure_nix_experimental_features() {
    log_info "Configuring Nix experimental features for flakes support..."
    
    # Create nix.conf if it doesn't exist
    local nix_conf_dir="$HOME/.config/nix"
    local nix_conf_file="$nix_conf_dir/nix.conf"
    
    # Create the directory if it doesn't exist
    mkdir -p "$nix_conf_dir"
    
    # Check if experimental features are already configured
    if [ -f "$nix_conf_file" ] && grep -q "experimental-features.*nix-command.*flakes" "$nix_conf_file"; then
        log_info "Experimental features already configured in $nix_conf_file"
        return 0
    fi
    
    # Add experimental features configuration
    log_info "Adding experimental features to $nix_conf_file"
    echo "# Enable experimental features for flakes and new nix commands" >> "$nix_conf_file"
    echo "experimental-features = nix-command flakes" >> "$nix_conf_file"
    
    # Also try to configure system-wide if we have sudo access
    if sudo -n true 2>/dev/null; then
        local system_nix_conf="/etc/nix/nix.conf"
        sudo mkdir -p "$(dirname "$system_nix_conf")"
        
        if [ ! -f "$system_nix_conf" ] || ! sudo grep -q "experimental-features.*nix-command.*flakes" "$system_nix_conf"; then
            log_info "Adding experimental features to system-wide configuration"
            echo "# Enable experimental features for flakes and new nix commands" | sudo tee -a "$system_nix_conf" > /dev/null
            echo "experimental-features = nix-command flakes" | sudo tee -a "$system_nix_conf" > /dev/null
            log_success "Configured system-wide experimental features"
        else
            log_info "System-wide experimental features already configured"
        fi
    else
        log_warn "Cannot configure system-wide experimental features (no sudo access)"
    fi
    
    log_success "Nix experimental features configured successfully"
}

# Helper function to show usage information
show_nix_usage_info() {
    log_info "To use Nix:"
    log_info "  nix --help                 # Show help"
    log_info "  nix-env -i <package>       # Install package"
    log_info "  nix-shell -p <package>     # Temporary shell with package"
    log_info "  nix develop                # Enter development shell (flakes)"
    log_info "  nix run <package>          # Run package (flakes)"
    log_info ""
    log_info "Note: Restart your shell or source the profile to use Nix commands"
    log_info "Experimental features (flakes) have been enabled for modern Nix usage"
}

# Run installation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if install_nix; then
        log_info "Nix installation completed successfully"
        exit 0
    else
        log_error "Nix installation failed"
        exit 1
    fi
fi
