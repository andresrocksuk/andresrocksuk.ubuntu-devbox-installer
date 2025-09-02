#!/bin/bash

# SSH Keys Setup for Users
# This script is designed to run as a regular user without complex logging dependencies

# Logging functions that don't require file permissions
log_info() { echo "[INFO] $1"; }
log_success() { echo "[SUCCESS] $1"; }
log_error() { echo "[ERROR] $1"; }
log_warn() { echo "[WARN] $1"; }

# Function to setup SSH keys for current user
setup_ssh_keys() {
    local config_file="${1:-/etc/wsl-devbox-config/install.yaml}"
    
    log_info "Setting up SSH keys for user: $(whoami)"
    
    # Skip if running as root
    if [[ "$EUID" -eq 0 || "$(whoami)" == "root" ]]; then
        log_info "SSH keys setup skipped: running as root user"
        return 0
    fi
    
    # Check if configuration file exists
    if [[ ! -f "$config_file" ]]; then
        log_info "SSH keys setup skipped: configuration file not found at $config_file"
        return 0
    fi
    
    # Check if yq is available
    if ! command -v yq >/dev/null 2>&1; then
        log_info "SSH keys setup skipped: yq not available"
        return 0
    fi
    
    # Check if git_ssh_keys section exists and is enabled
    if ! yq eval '.git_ssh_keys.enabled // false' "$config_file" | grep -q "true"; then
        log_info "SSH keys setup skipped: SSH keys configuration disabled"
        return 0
    fi
    
    # Get current user and Windows profile path
    local current_user=$(whoami)
    local windows_profile="/mnt/c/Users/$current_user"
    local windows_ssh_dir="$windows_profile/.ssh"
    
    log_info "Windows profile: $windows_profile"
    log_info "Windows SSH directory: $windows_ssh_dir"
    
    # Check if Windows user profile exists
    if [[ ! -d "$windows_profile" ]]; then
        log_info "SSH keys setup skipped: Windows user profile not found at $windows_profile"
        return 0
    fi
    
    # Check if Windows SSH directory exists
    if [[ ! -d "$windows_ssh_dir" ]]; then
        log_info "SSH keys setup skipped: Windows SSH directory not found at $windows_ssh_dir"
        return 0
    fi
    
    # Parse keys from configuration and check if they exist
    local keys_count=$(yq eval '.git_ssh_keys.keys | length' "$config_file")
    local keys_found=false
    
    if [[ "$keys_count" -eq 0 ]]; then
        log_info "SSH keys setup skipped: no SSH keys configured"
        return 0
    fi
    
    log_info "Checking for $keys_count configured SSH key(s)..."
    
    for ((i=0; i<keys_count; i++)); do
        local private_key=$(yq eval ".git_ssh_keys.keys[$i].private_key" "$config_file")
        local public_key=$(yq eval ".git_ssh_keys.keys[$i].public_key" "$config_file")
        local key_name=$(yq eval ".git_ssh_keys.keys[$i].name" "$config_file")
        
        local win_private_key="$windows_ssh_dir/$private_key"
        local win_public_key="$windows_ssh_dir/$public_key"
        
        log_info "Checking key '$key_name': $private_key, $public_key"
        
        if [[ -f "$win_private_key" && -f "$win_public_key" ]]; then
            log_info "Found SSH key pair for '$key_name'"
            keys_found=true
        else
            log_info "SSH key pair not found for '$key_name'"
        fi
    done
    
    if [[ "$keys_found" == "false" ]]; then
        log_info "SSH keys setup skipped: no configured SSH keys found in Windows profile"
        return 0
    fi
    
    log_success "SSH keys found in Windows profile, proceeding with setup"
    
    # Setup SSH directory structure
    local ssh_dir="$HOME/.ssh"
    log_info "Setting up SSH directory: $ssh_dir"
    
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        log_info "Created SSH directory: $ssh_dir"
    else
        log_info "SSH directory already exists: $ssh_dir"
    fi
    
    # Copy SSH keys
    log_info "Copying SSH keys from Windows profile..."
    
    for ((i=0; i<keys_count; i++)); do
        local private_key=$(yq eval ".git_ssh_keys.keys[$i].private_key" "$config_file")
        local public_key=$(yq eval ".git_ssh_keys.keys[$i].public_key" "$config_file")
        local key_name=$(yq eval ".git_ssh_keys.keys[$i].name" "$config_file")
        
        local win_private_key="$windows_ssh_dir/$private_key"
        local win_public_key="$windows_ssh_dir/$public_key"
        local wsl_private_key="$ssh_dir/$private_key"
        local wsl_public_key="$ssh_dir/$public_key"
        
        # Skip if Windows keys don't exist
        if [[ ! -f "$win_private_key" || ! -f "$win_public_key" ]]; then
            log_warn "Skipping key '$key_name': files not found in Windows profile"
            continue
        fi
        
        log_info "Copying key '$key_name'..."
        
        # Remove existing files
        [[ -e "$wsl_private_key" ]] && rm -f "$wsl_private_key"
        [[ -e "$wsl_public_key" ]] && rm -f "$wsl_public_key"
        
        # Copy files
        if cp "$win_private_key" "$wsl_private_key" && cp "$win_public_key" "$wsl_public_key"; then
            # Set proper permissions
            chmod 600 "$wsl_private_key"
            chmod 644 "$wsl_public_key"
            log_success "Copied SSH key '$key_name'"
        else
            log_error "Failed to copy SSH key '$key_name'"
        fi
    done
    
    # Generate SSH config file
    log_info "Generating SSH configuration..."
    generate_ssh_config "$config_file"
    
    # Configure SSH agent for shell
    log_info "Configuring SSH agent for shell..."
    configure_ssh_agent "$config_file"
    
    log_success "SSH keys setup completed successfully!"
    log_info "SSH keys are now available in: $ssh_dir"
    log_info "SSH configuration file: $ssh_dir/config"
    
    return 0
}

# Function to generate SSH config file
generate_ssh_config() {
    local config_file="$1"
    local ssh_config="$HOME/.ssh/config"
    local temp_config="$ssh_config.tmp"
    
    # Start with existing config if it exists
    if [[ -f "$ssh_config" ]]; then
        cp "$ssh_config" "$temp_config"
    else
        touch "$temp_config"
    fi
    
    # Add a marker for our configurations
    echo "" >> "$temp_config"
    echo "# WSL DevBox SSH Configuration - Generated $(date)" >> "$temp_config"
    
    # Parse keys and their host configurations
    local keys_count=$(yq eval '.git_ssh_keys.keys | length' "$config_file")
    
    for ((i=0; i<keys_count; i++)); do
        local key_name=$(yq eval ".git_ssh_keys.keys[$i].name" "$config_file")
        local private_key=$(yq eval ".git_ssh_keys.keys[$i].private_key" "$config_file")
        local hosts_count=$(yq eval ".git_ssh_keys.keys[$i].hosts | length" "$config_file")
        
        for ((j=0; j<hosts_count; j++)); do
            local host_name=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].name" "$config_file")
            local hostname=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].hostname" "$config_file")
            local user=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].user" "$config_file")
            local port=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].port // \"\"" "$config_file")
            local identities_only=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].identities_only // \"\"" "$config_file")
            
            # Add host configuration
            echo "" >> "$temp_config"
            echo "Host $host_name" >> "$temp_config"
            echo "    HostName $hostname" >> "$temp_config"
            echo "    User $user" >> "$temp_config"
            echo "    IdentityFile ~/.ssh/$private_key" >> "$temp_config"
            
            # Add optional properties
            [[ -n "$port" && "$port" != "null" ]] && echo "    Port $port" >> "$temp_config"
            
            # Handle boolean values for identities_only
            if [[ -n "$identities_only" && "$identities_only" != "null" ]]; then
                local identities_value=$(echo "$identities_only" | tr '[:upper:]' '[:lower:]')
                if [[ "$identities_value" == "true" ]]; then
                    echo "    IdentitiesOnly yes" >> "$temp_config"
                elif [[ "$identities_value" == "false" ]]; then
                    echo "    IdentitiesOnly no" >> "$temp_config"
                fi
            fi
            
            log_info "Added SSH host configuration: $host_name -> $hostname"
        done
    done
    
    # Move temp config to final location
    mv "$temp_config" "$ssh_config"
    chmod 600 "$ssh_config"
    
    log_success "SSH config file updated: $ssh_config"
}

# Function to configure SSH agent
configure_ssh_agent() {
    local config_file="$1"
    
    # Determine shell profile
    local shell_profile=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_profile="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        shell_profile="$HOME/.bashrc"
    else
        shell_profile="$HOME/.profile"
    fi
    
    # SSH agent startup script
    local ssh_agent_config='
# SSH Agent Configuration - WSL DevBox
if [ -z "$SSH_AUTH_SOCK" ]; then
    # Check for existing ssh-agent
    if [ -f ~/.ssh/ssh-agent.env ]; then
        source ~/.ssh/ssh-agent.env >/dev/null
    fi
    
    # Test if ssh-agent is responsive
    if ! ssh-add -l >/dev/null 2>&1; then
        # Start new ssh-agent
        ssh-agent > ~/.ssh/ssh-agent.env
        source ~/.ssh/ssh-agent.env >/dev/null
        
        # Add keys to agent
        if [ -f ~/.ssh/config ]; then
            # Extract IdentityFile paths from SSH config
            if grep -q "IdentityFile" ~/.ssh/config 2>/dev/null; then
                grep "IdentityFile" ~/.ssh/config | awk "{print \$2}" | sed "s|~|$HOME|g" | while read keyfile; do
                    if [ -f "$keyfile" ]; then
                        ssh-add "$keyfile" 2>/dev/null || true
                    fi
                done
            fi
        fi
    fi
fi'
    
    # Check if SSH agent config already exists
    if ! grep -q "SSH Agent Configuration - WSL DevBox" "$shell_profile" 2>/dev/null; then
        echo "$ssh_agent_config" >> "$shell_profile"
        log_success "Added SSH agent configuration to $shell_profile"
    else
        log_info "SSH agent configuration already exists in $shell_profile"
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_ssh_keys "$@"
fi
