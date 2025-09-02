#!/bin/bash

# SSH Keys Skeleton Configuration Script
# This script sets up SSH key configuration for new users as part of the skeleton system
# It should be called during user creation to automatically configure SSH keys if they exist

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/utils"

# Source utilities if available
if [ -f "$UTILS_DIR/logger.sh" ]; then
    source "$UTILS_DIR/logger.sh"
    source "$UTILS_DIR/security-helpers.sh"
else
    # Standalone logging functions
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_debug() { echo "[DEBUG] $1"; }
fi

# SSH Keys Skeleton Setup
# This script is designed to be placed in /etc/skel/ and executed during user creation
setup_ssh_keys_skeleton() {
    local config_file="${1:-/etc/wsl-devbox-config/install.yaml}"
    local target_user="$2"
    
    log_info "Setting up SSH keys skeleton configuration"
    log_info "Target user: ${target_user:-$(whoami)}"
    log_info "Config file: $config_file"
    
    # If no specific user provided, use current user
    if [[ -z "$target_user" ]]; then
        target_user="$(whoami)"
    fi
    
    # Skip if running as root
    if [[ "$target_user" == "root" || "$EUID" -eq 0 ]]; then
        log_info "SSH keys skeleton setup skipped: running as root user"
        return 0
    fi
    
    # Validate user context matches Windows user path
    local expected_windows_path="/mnt/c/Users/$target_user"
    if [[ ! -d "$expected_windows_path" ]]; then
        log_info "SSH keys skeleton setup skipped: no Windows user profile at $expected_windows_path"
        return 0
    fi
    
    log_info "Found Windows user profile: $expected_windows_path"
    
    # Check if configuration file exists
    if [[ ! -f "$config_file" ]]; then
        log_info "SSH keys skeleton setup skipped: configuration file not found at $config_file"
        return 0
    fi
    
    # Check if git_ssh_keys section exists and is enabled
    if ! command -v yq >/dev/null 2>&1; then
        log_info "SSH keys skeleton setup skipped: yq not available"
        return 0
    fi
    
    if ! yq eval '.git_ssh_keys.enabled // false' "$config_file" | grep -q "true"; then
        log_info "SSH keys skeleton setup skipped: SSH keys configuration disabled or not present"
        return 0
    fi
    
    # Check if SSH keys exist in Windows profile
    local windows_ssh_dir="$expected_windows_path/.ssh"
    if [[ ! -d "$windows_ssh_dir" ]]; then
        log_info "SSH keys skeleton setup skipped: Windows SSH directory not found at $windows_ssh_dir"
        return 0
    fi
    
    # Parse keys from configuration and check if they exist
    local keys_count=$(yq eval '.git_ssh_keys.keys | length' "$config_file")
    local keys_found=false
    
    if [[ "$keys_count" -eq 0 ]]; then
        log_info "SSH keys skeleton setup skipped: no SSH keys configured"
        return 0
    fi
    
    for ((i=0; i<keys_count; i++)); do
        local private_key=$(yq eval ".git_ssh_keys.keys[$i].private_key" "$config_file")
        local public_key=$(yq eval ".git_ssh_keys.keys[$i].public_key" "$config_file")
        local key_name=$(yq eval ".git_ssh_keys.keys[$i].name" "$config_file")
        
        local win_private_key="$windows_ssh_dir/$private_key"
        local win_public_key="$windows_ssh_dir/$public_key"
        
        if [[ -f "$win_private_key" && -f "$win_public_key" ]]; then
            log_info "Found SSH key pair for $key_name in Windows profile"
            keys_found=true
            break
        fi
    done
    
    if [[ "$keys_found" == "false" ]]; then
        log_info "SSH keys skeleton setup skipped: no configured SSH keys found in Windows profile"
        return 0
    fi
    
    log_success "SSH keys found in Windows profile, proceeding with skeleton configuration"
    
    # Execute the main SSH configuration script
    local ssh_config_script="/etc/wsl-devbox-config/configure-ssh-keys.sh"
    if [[ -f "$ssh_config_script" ]]; then
        log_info "Executing SSH keys configuration script"
        bash "$ssh_config_script" "$config_file"
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_success "SSH keys skeleton configuration completed successfully"
        else
            log_warn "SSH keys skeleton configuration completed with warnings (exit code: $exit_code)"
        fi
        
        return $exit_code
    else
        log_error "SSH keys configuration script not found at $ssh_config_script"
        return 1
    fi
}

# Install skeleton system integration
install_ssh_skeleton_system() {
    log_info "Installing SSH keys skeleton system"
    
    # Only proceed if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        log_error "Cannot install skeleton system: no sudo access"
        return 1
    fi
    
    # Create system configuration directory
    local system_config_dir="/etc/wsl-devbox-config"
    if [[ ! -d "$system_config_dir" ]]; then
        sudo mkdir -p "$system_config_dir"
        log_info "Created system configuration directory: $system_config_dir"
    fi
    
    # Copy configuration file to system location if it doesn't exist
    local source_config="$(dirname "$SCRIPT_DIR")/install.yaml"
    local system_config="$system_config_dir/install.yaml"
    
    if [[ -f "$source_config" && ! -f "$system_config" ]]; then
        sudo cp "$source_config" "$system_config"
        sudo chmod 644 "$system_config"
        log_info "Copied configuration to system location: $system_config"
    fi
    
    # Create skeleton script for new users
    local skeleton_script="/etc/skel/.ssh-keys-setup.sh"
    sudo tee "$skeleton_script" > /dev/null << 'EOF'
#!/bin/bash
# SSH Keys Auto-Setup Script for New Users
# This script is automatically executed for new users to set up SSH keys

# Use the simple SSH setup script that doesn't require complex logging
if [[ -f "/etc/wsl-devbox-config/ssh-keys-setup.sh" ]]; then
    bash "/etc/wsl-devbox-config/ssh-keys-setup.sh" "/etc/wsl-devbox-config/install.yaml"
else
    # Fallback to the original method
    if [[ -f "/etc/wsl-devbox-config/ssh-keys-skeleton.sh" ]]; then
        bash "/etc/wsl-devbox-config/ssh-keys-skeleton.sh" "setup" "/etc/wsl-devbox-config/install.yaml" "$(whoami)"
    fi
fi
EOF
    
    sudo chmod +x "$skeleton_script"
    log_info "Created skeleton script: $skeleton_script"
    
    # Copy this script to system location
    local system_skeleton_script="/etc/wsl-devbox-config/ssh-keys-skeleton.sh"
    sudo cp "$0" "$system_skeleton_script"
    sudo chmod +x "$system_skeleton_script"
    log_info "Installed skeleton script to system location: $system_skeleton_script"
    
    # Copy main SSH configuration script to system location and patch paths
    local main_ssh_script="$SCRIPT_DIR/configure-ssh-keys.sh"
    local system_ssh_script="/etc/wsl-devbox-config/configure-ssh-keys.sh"
    if [[ -f "$main_ssh_script" ]]; then
        # Copy and patch the script to use system paths
        sudo cp "$main_ssh_script" "$system_ssh_script"
        
        # Update the paths in the copied script
        sudo sed -i 's|UTILS_DIR="$(dirname "$SCRIPT_DIR")/utils"|UTILS_DIR="/etc/wsl-devbox-config/utils"|g' "$system_ssh_script"
        
        sudo chmod +x "$system_ssh_script"
        log_info "Installed and patched main SSH configuration script to system location: $system_ssh_script"
    else
        log_warn "Main SSH configuration script not found at $main_ssh_script"
    fi

    # Copy the simple SSH setup script for user-friendly execution
    local simple_ssh_script="$SCRIPT_DIR/ssh-keys-setup.sh"
    local system_simple_script="/etc/wsl-devbox-config/ssh-keys-setup.sh"
    if [[ -f "$simple_ssh_script" ]]; then
        sudo cp "$simple_ssh_script" "$system_simple_script"
        sudo chmod +x "$system_simple_script"
        log_info "Installed simple SSH setup script to system location: $system_simple_script"
    else
        log_warn "Simple SSH setup script not found at $simple_ssh_script"
        # Create a basic version inline if the external script doesn't exist
        sudo tee "$system_simple_script" > /dev/null << 'SIMPLESSHEOF'
#!/bin/bash
# Basic SSH Keys Setup for Users (inline version)
# This is a fallback when the external ssh-keys-setup.sh is not available

echo "[INFO] Basic SSH keys setup for user: $(whoami)"

# Skip if running as root
if [[ "$EUID" -eq 0 || "$(whoami)" == "root" ]]; then
    echo "[INFO] SSH keys setup skipped: running as root user"
    exit 0
fi

# Basic SSH directory setup
ssh_dir="$HOME/.ssh"
if [[ ! -d "$ssh_dir" ]]; then
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    echo "[INFO] Created SSH directory: $ssh_dir"
fi

# Try to copy common SSH keys from Windows profile
current_user=$(whoami)
windows_ssh_dir="/mnt/c/Users/$current_user/.ssh"

if [[ -d "$windows_ssh_dir" ]]; then
    echo "[INFO] Found Windows SSH directory: $windows_ssh_dir"
    
    # Copy common key types
    for key_type in "id_rsa" "id_ed25519" "id_ecdsa"; do
        if [[ -f "$windows_ssh_dir/$key_type" && -f "$windows_ssh_dir/$key_type.pub" ]]; then
            cp "$windows_ssh_dir/$key_type" "$ssh_dir/" 2>/dev/null
            cp "$windows_ssh_dir/$key_type.pub" "$ssh_dir/" 2>/dev/null
            chmod 600 "$ssh_dir/$key_type" 2>/dev/null
            chmod 644 "$ssh_dir/$key_type.pub" 2>/dev/null
            echo "[SUCCESS] Copied SSH key: $key_type"
        fi
    done
else
    echo "[INFO] Windows SSH directory not found: $windows_ssh_dir"
fi

echo "[INFO] Basic SSH setup completed"
SIMPLESSHEOF
        sudo chmod +x "$system_simple_script"
        log_info "Created basic SSH setup script at system location: $system_simple_script"
    fi
    
    # Copy utility scripts to system location
    local utils_dir="$UTILS_DIR"
    local system_utils_dir="/etc/wsl-devbox-config/utils"
    if [[ -d "$utils_dir" ]]; then
        sudo mkdir -p "$system_utils_dir"
        sudo cp "$utils_dir/logger.sh" "$system_utils_dir/" 2>/dev/null || true
        sudo cp "$utils_dir/security-helpers.sh" "$system_utils_dir/" 2>/dev/null || true
        sudo chmod +x "$system_utils_dir"/*.sh 2>/dev/null || true
        log_info "Installed utility scripts to system location: $system_utils_dir"
    else
        log_warn "Utility directory not found at $utils_dir"
    fi
    
    # Add execution to skeleton .bashrc, .profile, and .zshrc
    local ssh_setup_call='
# SSH Keys Auto-Setup - WSL DevBox
if [[ -f "$HOME/.ssh-keys-setup.sh" && ! -f "$HOME/.ssh-keys-configured" ]]; then
    bash "$HOME/.ssh-keys-setup.sh" && touch "$HOME/.ssh-keys-configured"
fi'

    # Create zsh integration for SSH keys
    local zsh_ssh_config='/usr/local/share/ssh-keys/ssh-keys.zsh'
    sudo mkdir -p "$(dirname "$zsh_ssh_config")"
    sudo tee "$zsh_ssh_config" > /dev/null << 'ZSHEOF'
# SSH Keys Auto-Setup for Zsh - WSL DevBox
# This script is sourced by zsh configuration to check and configure SSH keys

# Function to check and setup SSH keys on zsh load
ssh_keys_auto_setup() {
    # Only run if not already configured and SSH setup script exists
    if [[ -f "$HOME/.ssh-keys-setup.sh" && ! -f "$HOME/.ssh-keys-configured" ]]; then
        # Run silently on zsh load
        bash "$HOME/.ssh-keys-setup.sh" >/dev/null 2>&1 && touch "$HOME/.ssh-keys-configured"
    fi
    
    # Always check if SSH agent is running and keys are loaded
    if [[ -n "$SSH_AUTH_SOCK" ]] && command -v ssh-add >/dev/null 2>&1; then
        # Check if keys are loaded in SSH agent
        if ! ssh-add -l >/dev/null 2>&1; then
            # Try to load keys from SSH config if they exist
            if [[ -f "$HOME/.ssh/config" ]]; then
                grep "IdentityFile" "$HOME/.ssh/config" 2>/dev/null | awk '{print $2}' | sed "s|~|$HOME|g" | while read keyfile; do
                    if [[ -f "$keyfile" ]]; then
                        ssh-add "$keyfile" >/dev/null 2>&1 || true
                    fi
                done
            fi
        fi
    fi
}

# Run SSH keys auto-setup
ssh_keys_auto_setup
ZSHEOF
    
    sudo chmod +x "$zsh_ssh_config"
    log_success "Created zsh SSH keys integration: $zsh_ssh_config"
    
    # Update skeleton files using the existing environment-setup function
    if [[ -f "$UTILS_DIR/environment-setup.sh" ]]; then
        source "$UTILS_DIR/environment-setup.sh"
        update_skeleton_files "$ssh_setup_call" "SSH Keys Auto-Setup - WSL DevBox"
        log_success "Updated skeleton files with SSH keys auto-setup"
    else
        log_warn "Could not find environment-setup.sh, manually updating skeleton files"
        
        local skel_files=("/etc/skel/.bashrc" "/etc/skel/.profile")
        for skel_file in "${skel_files[@]}"; do
            if ! sudo grep -q "SSH Keys Auto-Setup - WSL DevBox" "$skel_file" 2>/dev/null; then
                echo "" | sudo tee -a "$skel_file" > /dev/null
                echo "# SSH Keys Auto-Setup - WSL DevBox" | sudo tee -a "$skel_file" > /dev/null
                echo "$ssh_setup_call" | sudo tee -a "$skel_file" > /dev/null
                log_info "Updated $skel_file"
            fi
        done
    fi
    
    # Add zsh-specific SSH keys integration to skeleton .zshrc
    local zsh_skel_file="/etc/skel/.zshrc"
    if [[ -f "$zsh_skel_file" ]]; then
        if ! sudo grep -q "SSH Keys Auto-Setup - WSL DevBox" "$zsh_skel_file" 2>/dev/null; then
            echo "" | sudo tee -a "$zsh_skel_file" > /dev/null
            echo "# SSH Keys Auto-Setup - WSL DevBox" | sudo tee -a "$zsh_skel_file" > /dev/null
            echo "source /usr/local/share/ssh-keys/ssh-keys.zsh 2>/dev/null || true" | sudo tee -a "$zsh_skel_file" > /dev/null
            log_success "Updated $zsh_skel_file with SSH keys zsh integration"
        else
            log_info "SSH keys configuration already exists in $zsh_skel_file"
        fi
    else
        log_warn "Skeleton .zshrc not found, creating basic version"
        sudo tee "$zsh_skel_file" > /dev/null << 'ZSHSKELF'
# Basic .zshrc skeleton

# SSH Keys Auto-Setup - WSL DevBox
source /usr/local/share/ssh-keys/ssh-keys.zsh 2>/dev/null || true
ZSHSKELF
        log_info "Created basic skeleton .zshrc with SSH keys integration"
    fi
    
    log_success "SSH keys skeleton system installation completed"
    log_info "New users will automatically have SSH keys configured if they exist in Windows profile"
    
    return 0
}

# Main function
main() {
    local action="${1:-setup}"
    local config_file="${2:-/etc/wsl-devbox-config/install.yaml}"
    local target_user="$3"
    
    case "$action" in
        "setup")
            setup_ssh_keys_skeleton "$config_file" "$target_user"
            ;;
        "install-system")
            install_ssh_skeleton_system
            ;;
        "")
            # Handle empty action (default to setup)
            setup_ssh_keys_skeleton "$config_file" "$target_user"
            ;;
        *)
            log_info "Usage: $0 [setup|install-system] [config_file] [target_user]"
            log_info "  setup          - Set up SSH keys for current/target user (default)"
            log_info "  install-system - Install the skeleton system for new users"
            log_info "  config_file    - Path to install.yaml (default: /etc/wsl-devbox-config/install.yaml)"
            log_info "  target_user    - Target user for setup (default: current user)"
            return 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
