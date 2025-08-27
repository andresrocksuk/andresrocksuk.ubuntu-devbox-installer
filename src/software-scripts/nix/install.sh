#!/bin/bash

# nix installation script
# Installs Nix package manager

set -e

# Get script directory for utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/../utils"

# Source utilities if available
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
    log_info "Installing Nix package manager..."
    
    # Check if already installed
    if command -v nix >/dev/null 2>&1; then
        local current_version=$(nix --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "Nix is already installed (version: $current_version)"
        return 0
    fi
    
    # Check if running as root - Nix installation as root has issues
    if [ "$EUID" -eq 0 ]; then
        log_info "Running as root, using alternative Nix installation method..."
        
        # Clean up any existing nixbld group/users that might conflict
        log_info "Cleaning up any existing Nix build users..."
        for i in $(seq 1 32); do
            if id "nixbld$i" >/dev/null 2>&1; then
                sudo userdel "nixbld$i" 2>/dev/null || true
            fi
        done
        
        if getent group nixbld >/dev/null 2>&1; then
            sudo groupdel nixbld 2>/dev/null || true
        fi
        
        # Use the multi-user installer
        log_info "Downloading Nix multi-user installer..."
        local installer_url="https://nixos.org/nix/install"
        local temp_installer="/tmp/nix-installer.sh"
        
        if command -v curl >/dev/null 2>&1; then
            curl -L "$installer_url" -o "$temp_installer"
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$temp_installer" "$installer_url"
        else
            log_error "Neither curl nor wget available for downloading"
            return 1
        fi
        
        # Make installer executable
        chmod +x "$temp_installer"
        
        # Install Nix in multi-user mode
        log_info "Installing Nix (multi-user mode)..."
        sh "$temp_installer" --daemon --yes
        
        # Clean up installer
        rm -f "$temp_installer"
        
        # Source Nix environment for multi-user installation
        if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
            log_info "Sourcing Nix daemon environment..."
            source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        fi
        
    else
        # Original single-user installation for non-root users
        # Check if /nix directory already exists
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
        
        # Download and install Nix
        log_info "Downloading Nix installer..."
        
        # Use the official Nix installer
        local installer_url="https://nixos.org/nix/install"
        local temp_installer="/tmp/nix-installer.sh"
        
        if command -v curl >/dev/null 2>&1; then
            curl -L "$installer_url" -o "$temp_installer"
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$temp_installer" "$installer_url"
        else
            log_error "Neither curl nor wget available for downloading"
            return 1
        fi
        
        # Make installer executable
        chmod +x "$temp_installer"
        
        # Install Nix in single-user mode for non-root
        log_info "Installing Nix (single-user mode)..."
        sh "$temp_installer" --no-daemon
        
        # Clean up installer
        rm -f "$temp_installer"
        
        # Source Nix environment
        if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
            log_info "Sourcing Nix environment..."
            source "$HOME/.nix-profile/etc/profile.d/nix.sh"
        fi
    fi
    
    # Add to shell profiles
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
            # Create system-wide environment setup for nix
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
            
            # Update skeleton files for new users
            setup_nix_skeleton_files "$nix_profile_script"
            
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
        else
            log_warn "Cannot setup system-wide environment (no sudo access)"
        fi
        
        # Use environment setup utility if available for additional setup
        if command -v source_script_in_profiles >/dev/null 2>&1; then
            source_script_in_profiles "$nix_profile_script" "Nix package manager environment"
        else
            # Fallback to original method
            setup_nix_environment_fallback "$nix_profile_script"
        fi
    fi
    
    # Verify installation
    if command -v nix >/dev/null 2>&1; then
        local installed_version=$(nix --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "Nix installed successfully (version: $installed_version)"
        
        # Test run
        log_info "Testing Nix..."
        nix --help >/dev/null 2>&1 && log_success "Nix test successful"
        
        # Test sudo access if we have sudo privileges
        if sudo -n true 2>/dev/null; then
            log_info "Testing sudo access to Nix..."
            if sudo nix --version >/dev/null 2>&1; then
                log_success "Sudo access to Nix working correctly"
            else
                log_warn "Sudo access to Nix not working - you may need to restart your shell"
            fi
        fi
        
        return 0
    else
        log_error "Nix installation verification failed"
        log_info "Note: You may need to restart your shell or source the Nix profile manually"
        return 1
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

# Run installation
install_nix

# Configure experimental features after installation
configure_nix_experimental_features
