#!/bin/bash

# Homebrew Multi-User Installation Script for WSL/Linux
# This script installs Homebrew using a dedicated linuxbrew user for multi-user environments
#
# INSTALLATION METHOD:
# Downloads and installs Homebrew from release tarballs (no git required)
#
# REQUIREMENTS:
# - curl (for downloading tarballs)
# - tar (for extracting archives)
# - sudo access
# - build-essential packages (will be installed automatically)

# Get script directory for reliable path resolution
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../../utils"

# Source installation framework
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
else
    echo "Error: installation-framework.sh not found at $UTILS_DIR/installation-framework.sh"
    exit 1
fi

# Source package manager utilities
if [ -f "$UTILS_DIR/package-manager.sh" ]; then
    source "$UTILS_DIR/package-manager.sh"
fi

# Enable error handling
set -e

# Configuration
LINUXBREW_USER="linuxbrew"
HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"

# Main installation function
install_homebrew() {
    log_section "Installing Homebrew"

create_linuxbrew_user() {
    log_info "Creating dedicated linuxbrew user..."
    
    # Check if linuxbrew user already exists
    if id "$LINUXBREW_USER" >/dev/null 2>&1; then
        log_info "User '$LINUXBREW_USER' already exists"
        return 0
    fi
    
    # Check if linuxbrew group exists, if not create it with specific GID
    if ! getent group "$LINUXBREW_USER" >/dev/null 2>&1; then
        sudo groupadd -g 1500 "$LINUXBREW_USER"
        log_debug "Created group '$LINUXBREW_USER' with GID 1500"
    fi
    
    # Create the linuxbrew user with home directory, specific UID, and assign to linuxbrew group
    # Use UID 1500 to avoid conflict with default WSL user (UID 1000)
    if sudo useradd --create-home --uid 1500 --gid "$LINUXBREW_USER" "$LINUXBREW_USER"; then
        log_info "Successfully created user '$LINUXBREW_USER' with UID 1500"
        return 0
    else
        log_error "Failed to create user '$LINUXBREW_USER'"
        return 1
    fi
}

install_homebrew_for_linuxbrew_user() {
    log_info "Installing Homebrew for the linuxbrew user using release tarball..."
    
    # Check prerequisites
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed. Please install curl first."
        return 1
    fi
    
    if ! command -v tar >/dev/null 2>&1; then
        log_error "tar is required but not installed. Please install tar first."
        return 1
    fi
    
    # Install build dependencies if not already present
    log_info "Installing build dependencies..."
    if command -v apt-get; then
        log_debug "Using apt-get to install dependencies..."
        setup_noninteractive_apt
        if safe_apt_update; then
            safe_apt_install build-essential procps file curl tar
        else
            log_warn "Failed to update package lists, continuing anyway..."
        fi
    elif command -v yum >/dev/null 2>&1; then
        log_debug "Using yum to install dependencies..."
        sudo yum groupinstall -y 'Development Tools' >/dev/null 2>&1
        sudo yum install -y procps-ng file curl tar >/dev/null 2>&1
    else
        log_warn "No supported package manager found, assuming dependencies are available"
    fi
    
    # Create homebrew directory
    local homebrew_dir="$HOMEBREW_PREFIX"
    if sudo -u "$LINUXBREW_USER" mkdir -p "$homebrew_dir"; then
        log_debug "Created Homebrew directory: $homebrew_dir"
    else
        log_error "Failed to create Homebrew directory: $homebrew_dir"
        return 1
    fi
    
    # Download and extract Homebrew tarball
    log_info "Downloading latest Homebrew release tarball..."
    if sudo -H -i -u "$LINUXBREW_USER" /bin/bash -c "
        cd '$homebrew_dir' && 
        curl -L https://github.com/Homebrew/brew/tarball/main | tar xz --strip-components 1
    " 2>&1 | tee /tmp/homebrew-install.log; then
        log_info "Successfully downloaded and extracted Homebrew tarball"
    else
        local exit_code=$?
        log_error "Failed to download or extract Homebrew tarball (exit code: $exit_code)"
        if [ -f /tmp/homebrew-install.log ]; then
            log_debug "Installation log (last 10 lines):"
            tail -10 /tmp/homebrew-install.log | while read line; do
                log_debug "  $line"
            done
        fi
        return 1
    fi
    
    # Initialize Homebrew
    log_info "Initializing Homebrew installation..."
    if sudo -H -i -u "$LINUXBREW_USER" /bin/bash -c "
        export PATH='$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:\$PATH' && 
        '$HOMEBREW_PREFIX/bin/brew' update --force --quiet
    " 2>&1 | tee -a /tmp/homebrew-install.log; then
        log_info "Homebrew installation completed successfully for user '$LINUXBREW_USER'"
        return 0
    else
        local exit_code=$?
        log_error "Failed to initialize Homebrew installation (exit code: $exit_code)"
        if [ -f /tmp/homebrew-install.log ]; then
            log_debug "Installation log (last 10 lines):"
            tail -10 /tmp/homebrew-install.log | while read line; do
                log_debug "  $line"
            done
        fi
        return 1
    fi
}

install_homebrew_from_tarball() {
    log_info "Installing Homebrew from release tarball (git-free method)..."
    
    # Install build dependencies if not already present
    log_info "Installing build dependencies..."
    if command -v apt-get; then
        log_debug "Using apt-get to install dependencies..."
        if safe_apt_update; then
            safe_apt_install build-essential procps file curl tar
        else
            log_warn "Failed to update package lists, continuing anyway..."
        fi
    elif command -v yum >/dev/null 2>&1; then
        log_debug "Using yum to install dependencies..."
        sudo yum groupinstall -y 'Development Tools' >/dev/null 2>&1
        sudo yum install -y procps-ng file curl tar >/dev/null 2>&1
    else
        log_warn "No supported package manager found, assuming dependencies are available"
    fi
    
    # Create homebrew directory
    local homebrew_dir="$HOMEBREW_PREFIX"
    if sudo -u "$LINUXBREW_USER" mkdir -p "$homebrew_dir"; then
        log_debug "Created Homebrew directory: $homebrew_dir"
    else
        log_error "Failed to create Homebrew directory: $homebrew_dir"
        return 1
    fi
    
    # Download and extract Homebrew tarball
    log_info "Downloading latest Homebrew release tarball..."
    if sudo -H -i -u "$LINUXBREW_USER" /bin/bash -c "
        cd '$homebrew_dir' && \
        curl -L https://github.com/Homebrew/brew/tarball/main | tar xz --strip-components 1
    " 2>&1 | tee /tmp/homebrew-tarball-install.log; then
        log_info "Successfully downloaded and extracted Homebrew tarball"
    else
        local exit_code=$?
        log_error "Failed to download or extract Homebrew tarball (exit code: $exit_code)"
        if [ -f /tmp/homebrew-tarball-install.log ]; then
            log_debug "Installation log (last 10 lines):"
            tail -10 /tmp/homebrew-tarball-install.log | while read line; do
                log_debug "  $line"
            done
        fi
        return 1
    fi
    
    # Initialize Homebrew
    log_info "Initializing Homebrew installation..."
    if sudo -H -i -u "$LINUXBREW_USER" /bin/bash -c "
        export PATH='$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:\$PATH' && \
        '$HOMEBREW_PREFIX/bin/brew' update --force --quiet
    " 2>&1 | tee -a /tmp/homebrew-tarball-install.log; then
        log_info "Homebrew installation from tarball completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "Failed to initialize Homebrew installation (exit code: $exit_code)"
        if [ -f /tmp/homebrew-tarball-install.log ]; then
            log_debug "Installation log (last 10 lines):"
            tail -10 /tmp/homebrew-tarball-install.log | while read line; do
                log_debug "  $line"
            done
        fi
        return 1
    fi
}

install_homebrew_from_git() {
    log_info "Installing Homebrew using standard git-based method..."
    
    # Install build dependencies if not already present
    log_info "Installing build dependencies..."
    if command -v apt-get; then
        log_debug "Using apt-get to install dependencies..."
        if safe_apt_update; then
            safe_apt_install build-essential procps file git curl
        else
            log_warn "Failed to update package lists, continuing anyway..."
        fi
    elif command -v yum >/dev/null 2>&1; then
        log_debug "Using yum to install dependencies..."
        sudo yum groupinstall -y 'Development Tools' >/dev/null 2>&1
        sudo yum install -y procps-ng file git curl >/dev/null 2>&1
    else
        log_warn "No supported package manager found, assuming dependencies are available"
    fi
    
    # Install Homebrew as the linuxbrew user
    log_info "Running Homebrew installation script as linuxbrew user..."
    
    # Set environment variables for non-interactive installation
    export NONINTERACTIVE=1
    export CI=1
    
    # Run the official Homebrew installation script as the linuxbrew user
    if sudo -H -i -u "$LINUXBREW_USER" /bin/bash -c 'export NONINTERACTIVE=1; export CI=1; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' 2>&1 | tee /tmp/homebrew-install.log; then
        log_info "Homebrew installation completed successfully for user '$LINUXBREW_USER'"
        return 0
    else
        local exit_code=$?
        log_error "Homebrew installation failed (exit code: $exit_code)"
        if [ -f /tmp/homebrew-install.log ]; then
            log_debug "Installation log (last 10 lines):"
            tail -10 /tmp/homebrew-install.log | while read line; do
                log_debug "  $line"
            done
        fi
        return 1
    fi
}

setup_homebrew_permissions() {
    log_info "Setting up Homebrew permissions for multi-user access..."
    
    # Make Homebrew directory accessible to all users as per the official guide
    if [ -d "/home/linuxbrew" ]; then
        log_debug "Making Homebrew directories executable for all users..."
        sudo chmod -R a+x /home/linuxbrew
        log_info "Homebrew permissions configured for multi-user access"
        return 0
    else
        log_error "Homebrew directory not found at /home/linuxbrew"
        return 1
    fi
}

create_brew_alias_configuration() {
    log_info "Creating brew alias configuration for multi-user access..."
    
    # Create a configuration file that sets up the brew alias
    local homebrew_config_dir="/usr/local/share/homebrew"
    local homebrew_config_file="$homebrew_config_dir/homebrew.zsh"
    
    if sudo mkdir -p "$homebrew_config_dir"; then
        sudo tee "$homebrew_config_file" > /dev/null << EOF
# Homebrew Multi-User Configuration
# This configuration sets up Homebrew access via the dedicated linuxbrew user

# Check if Homebrew is installed and accessible
if [ -x "$HOMEBREW_PREFIX/bin/brew" ] && [ -d "$HOMEBREW_PREFIX" ]; then
    # Set up environment using Homebrew's shellenv for proper PATH, MANPATH, etc
    eval "\$($HOMEBREW_PREFIX/bin/brew shellenv)"
    
    # Create alias to run brew commands as the linuxbrew user
    alias brew="sudo -H -i -u $LINUXBREW_USER $HOMEBREW_PREFIX/bin/brew"
fi
EOF
        sudo chmod 644 "$homebrew_config_file"
        log_info "Created Homebrew configuration at $homebrew_config_file"
        return 0
    else
        log_error "Failed to create Homebrew configuration directory"
        return 1
    fi
}

setup_skeleton_files_for_multiuser() {
    log_info "Setting up skeleton files for multi-user Homebrew access..."
    
        # Use the environment setup utility if available
        if command -v update_skeleton_files >/dev/null 2>&1; then
            local homebrew_config='# Homebrew Multi-User Setup
# Check if Homebrew is installed and accessible
if [ -x "'$HOMEBREW_PREFIX'/bin/brew" ] && [ -d "'$HOMEBREW_PREFIX'" ]; then
    # Set up environment using Homebrew shellenv for proper PATH, MANPATH, etc
    eval "$('$HOMEBREW_PREFIX'/bin/brew shellenv)"
    
    # Create alias to run brew commands as the linuxbrew user
    alias brew="sudo -H -i -u '$LINUXBREW_USER' '$HOMEBREW_PREFIX'/bin/brew"
fi'        update_skeleton_files "$homebrew_config" "Homebrew multi-user environment setup"
        log_info "Updated skeleton files using environment setup utility"
    else
        # Fallback method - only update bash/profile files
        log_info "Using fallback method to update skeleton files..."
        
        local skel_files=("/etc/skel/.bashrc" "/etc/skel/.profile")
        
        for skel_file in "${skel_files[@]}"; do
            if [ -f "$skel_file" ]; then
                # Check if configuration already exists
                if ! sudo grep -q "Homebrew multi-user environment setup" "$skel_file" 2>/dev/null; then
                    echo "" | sudo tee -a "$skel_file" > /dev/null
                    echo "# Homebrew multi-user environment setup" | sudo tee -a "$skel_file" > /dev/null
                    echo '# Check if Homebrew is installed and accessible' | sudo tee -a "$skel_file" > /dev/null
                    echo 'if [ -x "'$HOMEBREW_PREFIX'/bin/brew" ] && [ -d "'$HOMEBREW_PREFIX'" ]; then' | sudo tee -a "$skel_file" > /dev/null
                    echo '    # Set up environment using Homebrew shellenv for proper PATH, MANPATH, etc' | sudo tee -a "$skel_file" > /dev/null
                    echo '    eval "$('$HOMEBREW_PREFIX'/bin/brew shellenv)"' | sudo tee -a "$skel_file" > /dev/null
                    echo '    ' | sudo tee -a "$skel_file" > /dev/null
                    echo '    # Create alias to run brew commands as the linuxbrew user' | sudo tee -a "$skel_file" > /dev/null
                    echo '    alias brew="sudo -H -i -u '$LINUXBREW_USER' '$HOMEBREW_PREFIX'/bin/brew"' | sudo tee -a "$skel_file" > /dev/null
                    echo 'fi' | sudo tee -a "$skel_file" > /dev/null
                    log_info "Updated $skel_file with Homebrew multi-user configuration"
                else
                    log_info "Homebrew configuration already exists in $skel_file"
                fi
            else
                # Create skeleton file if it doesn't exist
                log_info "Creating $skel_file"
                sudo mkdir -p "$(dirname "$skel_file")"
                echo "# Homebrew multi-user environment setup" | sudo tee "$skel_file" > /dev/null
                echo '# Check if Homebrew is installed and accessible' | sudo tee -a "$skel_file" > /dev/null
                echo 'if [ -x "'$HOMEBREW_PREFIX'/bin/brew" ] && [ -d "'$HOMEBREW_PREFIX'" ]; then' | sudo tee -a "$skel_file" > /dev/null
                echo '    # Set up environment using Homebrew shellenv for proper PATH, MANPATH, etc' | sudo tee -a "$skel_file" > /dev/null
                echo '    eval "$('$HOMEBREW_PREFIX'/bin/brew shellenv)"' | sudo tee -a "$skel_file" > /dev/null
                echo '    ' | sudo tee -a "$skel_file" > /dev/null
                echo '    # Create alias to run brew commands as the linuxbrew user' | sudo tee -a "$skel_file" > /dev/null
                echo '    alias brew="sudo -H -i -u '$LINUXBREW_USER' '$HOMEBREW_PREFIX'/bin/brew"' | sudo tee -a "$skel_file" > /dev/null
                echo 'fi' | sudo tee -a "$skel_file" > /dev/null
            fi
        done
    fi
}

create_sudo_configuration() {
    log_info "Creating sudo configuration for brew access..."
    
    # Create a sudoers file that allows users to run brew commands as linuxbrew user without password
    local sudoers_file="/etc/sudoers.d/homebrew"
    
    sudo tee "$sudoers_file" > /dev/null << EOF
# Allow all users to run brew commands as the linuxbrew user without password
# This is safe because brew operations don't require system-level privileges
%sudo ALL=(linuxbrew) NOPASSWD: $HOMEBREW_PREFIX/bin/brew
%admin ALL=(linuxbrew) NOPASSWD: $HOMEBREW_PREFIX/bin/brew
%wheel ALL=(linuxbrew) NOPASSWD: $HOMEBREW_PREFIX/bin/brew

# Also allow common groups that might exist
%users ALL=(linuxbrew) NOPASSWD: $HOMEBREW_PREFIX/bin/brew
ALL ALL=(linuxbrew) NOPASSWD: $HOMEBREW_PREFIX/bin/brew
EOF
    
    # Set proper permissions on the sudoers file
    sudo chmod 440 "$sudoers_file"
    
    # Validate the sudoers file
    if sudo visudo -c -f "$sudoers_file"; then
        log_info "Created sudo configuration for Homebrew at $sudoers_file"
        return 0
    else
        log_error "Invalid sudoers configuration, removing file"
        sudo rm -f "$sudoers_file"
        return 1
    fi
}

install_homebrew() {
    log_info "Starting Homebrew tarball-based installation..."
    
    # Check if homebrew is already installed and working
    if command -v brew >/dev/null 2>&1; then
        local current_version=$(brew --version 2>/dev/null | head -n 1 | cut -d' ' -f2)
        if [ -n "$current_version" ]; then
            log_info "Homebrew is already installed and working (version: $current_version)"
            return 0
        fi
    fi
    
    # Check if we need sudo access
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo access to create users and configure the system"
        return 1
    fi
    
    # Step 1: Create the linuxbrew user
    if ! create_linuxbrew_user; then
        log_error "Failed to create linuxbrew user"
        return 1
    fi
    
    # Step 2: Install Homebrew for the linuxbrew user using tarball
    if ! install_homebrew_for_linuxbrew_user; then
        log_error "Failed to install Homebrew for linuxbrew user"
        return 1
    fi
    
    # Step 3: Set up permissions
    if ! setup_homebrew_permissions; then
        log_error "Failed to setup Homebrew permissions"
        return 1
    fi
    
    # Step 4: Create sudo configuration
    if ! create_sudo_configuration; then
        log_warn "Failed to create sudo configuration, users will need to enter password for brew commands"
    fi
    
    # Step 5: Create system-wide configuration
    if ! create_brew_alias_configuration; then
        log_error "Failed to create brew alias configuration"
        return 1
    fi
    
    # Step 6: Setup skeleton files
    if ! setup_skeleton_files_for_multiuser; then
        log_warn "Failed to setup skeleton files, but Homebrew should still work"
    fi
    
    # Step 7: Set up current user's environment
    setup_current_user_environment
    
    log_info "Homebrew tarball-based installation completed successfully"
    log_info "Users can now run 'brew' commands which will execute as the linuxbrew user"
    log_info "The 'command -v brew' test should now work in non-interactive shells"
    log_info "Example: brew install package-name"
    
    return 0
}

setup_current_user_environment() {
    log_info "Setting up Homebrew environment for current user..."
    
    # Add to current session using shellenv for proper environment setup
    if [ -x "$HOMEBREW_PREFIX/bin/brew" ]; then
        # Use shellenv to get proper environment variables
        eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
        
        # Create the alias for the current session
        alias brew="sudo -H -i -u $LINUXBREW_USER $HOMEBREW_PREFIX/bin/brew"
        
        log_info "Homebrew environment configured for current session using shellenv"
    else
        log_warn "Homebrew binary not found at $HOMEBREW_PREFIX/bin/brew"
    fi
}

# Main execution
if install_homebrew; then
    log_info "Homebrew tarball-based installation completed successfully"
    log_success "Homebrew installed successfully and added to environment"
    return 0
else
    log_error "Homebrew tarball-based installation failed"
    return 1
fi
}

# Execute installation
install_homebrew "$@"
