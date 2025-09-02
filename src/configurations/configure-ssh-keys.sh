#!/bin/bash

# Configure SSH Keys for WSL User
# This script sets up SSH keys by creating symlinks from Windows user profile to WSL user profile
# and configures SSH agent and host configurations

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/utils"

# Source utilities
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/security-helpers.sh"

# Initialize
log_section "Starting SSH Keys Configuration"

# Function to check if running as root
check_not_root() {
    if [[ "$EUID" -eq 0 || "$(whoami)" == "root" ]]; then
        log_info "SSH keys configuration skipped: running as root user"
        log_info "SSH keys should be configured for regular users only"
        return 1
    fi
    return 0
}

# Function to validate user context matches Windows user path
validate_user_context() {
    local current_user=$(whoami)
    local expected_windows_path="/mnt/c/Users/$current_user"
    
    log_info "Validating user context for SSH configuration"
    log_info "Current WSL user: $current_user"
    log_info "Expected Windows profile path: $expected_windows_path"
    
    # Check if the expected Windows user directory exists
    if [[ ! -d "$expected_windows_path" ]]; then
        log_error "User context validation failed: Windows user directory not found at $expected_windows_path"
        log_error "SSH keys configuration requires WSL user to match Windows user profile"
        log_info "Current WSL user '$current_user' does not have corresponding Windows user profile"
        return 1
    fi
    
    log_success "User context validation passed: WSL user matches Windows user profile"
    return 0
}

# Function to check if SSH keys exist in Windows profile (skeleton configuration)
check_ssh_keys_exist() {
    local config_file="$1"
    local windows_profile="$2"
    local windows_ssh_dir="$windows_profile/.ssh"
    
    log_info "Checking if SSH keys exist in Windows profile (skeleton configuration)"
    log_info "Windows SSH directory: $windows_ssh_dir"
    
    # Check if Windows .ssh directory exists
    if [[ ! -d "$windows_ssh_dir" ]]; then
        log_info "Skeleton configuration: Windows SSH directory not found: $windows_ssh_dir"
        log_info "SSH keys configuration will be skipped - no SSH keys to configure"
        return 1
    fi
    
    # Parse keys from configuration and check if they exist
    local keys_count=$(yq eval '.git_ssh_keys.keys | length' "$config_file")
    local keys_found=false
    
    if [[ "$keys_count" -eq 0 ]]; then
        log_info "Skeleton configuration: No SSH keys configured in install.yaml"
        return 1
    fi
    
    for ((i=0; i<keys_count; i++)); do
        local private_key=$(yq eval ".git_ssh_keys.keys[$i].private_key" "$config_file")
        local public_key=$(yq eval ".git_ssh_keys.keys[$i].public_key" "$config_file")
        local key_name=$(yq eval ".git_ssh_keys.keys[$i].name" "$config_file")
        
        local win_private_key="$windows_ssh_dir/$private_key"
        local win_public_key="$windows_ssh_dir/$public_key"
        
        if [[ -f "$win_private_key" && -f "$win_public_key" ]]; then
            log_info "Skeleton configuration: Found SSH key pair for $key_name"
            keys_found=true
        else
            log_info "Skeleton configuration: SSH key pair not found for $key_name (private: $win_private_key, public: $win_public_key)"
        fi
    done
    
    if [[ "$keys_found" == "false" ]]; then
        log_info "Skeleton configuration: No configured SSH keys found in Windows profile"
        log_info "SSH keys configuration will be skipped - no SSH keys to configure"
        return 1
    fi
    
    log_success "Skeleton configuration: SSH keys found in Windows profile, proceeding with configuration"
    return 0
}

# Function to validate input parameters
validate_ssh_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Check if git_ssh_keys section exists and is enabled
    if ! yq eval '.git_ssh_keys.enabled // false' "$config_file" | grep -q "true"; then
        log_info "SSH keys configuration is disabled or not present"
        return 1
    fi
    
    return 0
}

# Function to get Windows user profile path
get_windows_user_profile() {
    local current_user=$(whoami)
    local expected_profile="/mnt/c/Users/$current_user"
    
    log_info "Getting Windows user profile for current user: $current_user"
    
    # First priority: Use the validated user context path
    if [[ -d "$expected_profile" ]]; then
        log_info "Using matching Windows user profile: $expected_profile"
        echo "$expected_profile"
        return 0
    fi
    
    # Fallback: Try to find any user profile that has .ssh directory (for compatibility)
    log_info "Primary user profile not found, checking for fallback options..."
    if [[ -d "/mnt/c/Users" ]]; then
        for user_dir in /mnt/c/Users/*/; do
            if [[ -d "${user_dir}.ssh" ]]; then
                local fallback_profile="${user_dir%/}"
                log_info "Found fallback Windows profile with SSH directory: $fallback_profile"
                echo "$fallback_profile"
                return 0
            fi
        done
    fi
    
    log_error "No suitable Windows user profile found"
    return 1
}

# Function to setup SSH directory structure
setup_ssh_directory() {
    local ssh_dir="$HOME/.ssh"
    
    log_info "Setting up SSH directory structure"
    
    # Create .ssh directory if it doesn't exist
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        log_info "Created SSH directory: $ssh_dir"
    else
        log_info "SSH directory already exists: $ssh_dir"
    fi
    
    return 0
}

# Function to create SSH key symlinks
create_ssh_key_symlinks() {
    local config_file="$1"
    local windows_profile="$2"
    local ssh_dir="$HOME/.ssh"
    local windows_ssh_dir="$windows_profile/.ssh"
    
    log_info "Creating SSH key copies from Windows profile"
    log_info "Windows profile: $windows_profile"
    log_info "Windows SSH directory: $windows_ssh_dir"
    
    # Check if Windows .ssh directory exists
    if [[ ! -d "$windows_ssh_dir" ]]; then
        log_error "Windows SSH directory not found: $windows_ssh_dir"
        log_error "Please ensure SSH keys exist in Windows user profile: $windows_profile/.ssh"
        return 1
    fi
    
    log_info "Windows SSH directory found: $windows_ssh_dir"
    
    # Parse keys from configuration
    local keys_count=$(yq eval '.git_ssh_keys.keys | length' "$config_file")
    
    if [[ "$keys_count" -eq 0 ]]; then
        log_info "No SSH keys configured"
        return 0
    fi
    
    for ((i=0; i<keys_count; i++)); do
        local private_key=$(yq eval ".git_ssh_keys.keys[$i].private_key" "$config_file")
        local public_key=$(yq eval ".git_ssh_keys.keys[$i].public_key" "$config_file")
        local key_name=$(yq eval ".git_ssh_keys.keys[$i].name" "$config_file")
        
        log_info "Processing SSH key pair: $key_name"
        
        # Validate key files exist on Windows side
        local win_private_key="$windows_ssh_dir/$private_key"
        local win_public_key="$windows_ssh_dir/$public_key"
        
        if [[ ! -f "$win_private_key" ]]; then
            log_error "Private key not found: $win_private_key"
            continue
        fi
        
        if [[ ! -f "$win_public_key" ]]; then
            log_error "Public key not found: $win_public_key"
            continue
        fi
        
        # Create copies (symlinks don't work well with SSH permissions)
        local wsl_private_key="$ssh_dir/$private_key"
        local wsl_public_key="$ssh_dir/$public_key"
        
        # Remove existing files
        [[ -e "$wsl_private_key" ]] && rm -f "$wsl_private_key"
        [[ -e "$wsl_public_key" ]] && rm -f "$wsl_public_key"
        
        # Copy files (not symlink) for proper permissions
        cp "$win_private_key" "$wsl_private_key"
        cp "$win_public_key" "$wsl_public_key"
        
        # Set proper permissions
        chmod 600 "$wsl_private_key"
        chmod 644 "$wsl_public_key"
        
        log_success "Created SSH key copies for $key_name:"
        log_info "  Private: $wsl_private_key (copied from $win_private_key)"
        log_info "  Public: $wsl_public_key (copied from $win_public_key)"
    done
    
    return 0
}

# Function to generate SSH config file
generate_ssh_config() {
    local config_file="$1"
    local ssh_config="$HOME/.ssh/config"
    local temp_config="$ssh_config.tmp"
    
    log_info "Generating SSH host configurations"
    
    # Start with existing config if it exists
    if [[ -f "$ssh_config" ]]; then
        log_info "Backing up existing SSH config"
        cp "$ssh_config" "$ssh_config.backup.$(date +%Y%m%d_%H%M%S)"
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
        
        log_info "Processing host configurations for key: $key_name"
        
        for ((j=0; j<hosts_count; j++)); do
            local host_name=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].name" "$config_file")
            local hostname=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].hostname" "$config_file")
            local user=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].user" "$config_file")
            local port=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].port // \"\"" "$config_file")
            local preferred_auth=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].preferred_authentications // \"\"" "$config_file")
            local identities_only=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].identities_only // \"\"" "$config_file")
            local forward_agent=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].forward_agent // \"\"" "$config_file")
            local alive_interval=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].server_alive_interval // \"\"" "$config_file")
            local alive_count_max=$(yq eval ".git_ssh_keys.keys[$i].hosts[$j].server_alive_count_max // \"\"" "$config_file")
            
            # Add host configuration
            echo "" >> "$temp_config"
            echo "Host $host_name" >> "$temp_config"
            echo "    HostName $hostname" >> "$temp_config"
            echo "    User $user" >> "$temp_config"
            echo "    IdentityFile ~/.ssh/$private_key" >> "$temp_config"
            
            # Only add optional properties if they are not null/empty
            [[ -n "$port" && "$port" != "null" ]] && echo "    Port $port" >> "$temp_config"
            [[ -n "$preferred_auth" && "$preferred_auth" != "null" ]] && echo "    PreferredAuthentications $preferred_auth" >> "$temp_config"
            
            # Handle boolean values for identities_only
            if [[ -n "$identities_only" && "$identities_only" != "null" ]]; then
                local identities_value=$(echo "$identities_only" | tr '[:upper:]' '[:lower:]')
                if [[ "$identities_value" == "true" ]]; then
                    echo "    IdentitiesOnly yes" >> "$temp_config"
                elif [[ "$identities_value" == "false" ]]; then
                    echo "    IdentitiesOnly no" >> "$temp_config"
                fi
            fi
            
            # Handle boolean values for forward_agent
            if [[ -n "$forward_agent" && "$forward_agent" != "null" ]]; then
                local forward_value=$(echo "$forward_agent" | tr '[:upper:]' '[:lower:]')
                if [[ "$forward_value" == "true" ]]; then
                    echo "    ForwardAgent yes" >> "$temp_config"
                elif [[ "$forward_value" == "false" ]]; then
                    echo "    ForwardAgent no" >> "$temp_config"
                fi
            fi
            
            # Only add interval settings if they are not null/empty
            [[ -n "$alive_interval" && "$alive_interval" != "null" ]] && echo "    ServerAliveInterval $alive_interval" >> "$temp_config"
            [[ -n "$alive_count_max" && "$alive_count_max" != "null" ]] && echo "    ServerAliveCountMax $alive_count_max" >> "$temp_config"
            
            log_success "Added SSH host configuration: $host_name -> $hostname"
        done
    done
    
    # Move temp config to final location
    mv "$temp_config" "$ssh_config"
    chmod 600 "$ssh_config"
    
    log_success "SSH config file updated: $ssh_config"
    return 0
}

# Function to configure SSH agent
configure_ssh_agent() {
    local config_file="$1"
    
    log_info "Configuring SSH agent"
    
    # Add SSH agent configuration to shell profile
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
    
    # Start SSH agent for current session and add keys
    if [[ -z "$SSH_AUTH_SOCK" ]]; then
        if eval "$(ssh-agent -s)" >/dev/null 2>&1; then
            log_info "SSH agent started for current session"
        else
            log_warning "Failed to start SSH agent for current session"
        fi
        
        # Add keys to current session
        local keys_count=$(yq eval '.git_ssh_keys.keys | length' "$config_file")
        for ((i=0; i<keys_count; i++)); do
            local private_key=$(yq eval ".git_ssh_keys.keys[$i].private_key" "$config_file")
            local key_path="$HOME/.ssh/$private_key"
            
            if [[ -f "$key_path" ]]; then
                if ssh-add "$key_path" 2>/dev/null; then
                    log_success "Added key to SSH agent: $private_key"
                else
                    log_warning "Failed to add key to SSH agent: $private_key"
                fi
            fi
        done
    fi
    
    return 0
}

# Main function
main() {
    local config_file="${1:-$SCRIPT_DIR/../install.yaml}"
    
    log_info "Starting SSH keys configuration with config: $config_file"
    
    # Check if running as root - skip SSH configuration for root user but install skeleton system
    if [[ "$EUID" -eq 0 || "$(whoami)" == "root" ]]; then
        log_info "SSH keys configuration skipped: running as root user"
        log_info "SSH keys should be configured for regular users only"
        
        # Install skeleton system when running as root
        log_info "Installing SSH keys skeleton system for new users (root context)"
        if ! install_ssh_keys_skeleton_system "$config_file"; then
            log_warn "SSH keys skeleton system installation failed"
        else
            log_success "SSH keys skeleton system installed successfully"
        fi
        
        return 0
    fi
    
    # Validate user context matches Windows user path
    if ! validate_user_context; then
        log_info "SSH keys configuration skipped due to user context mismatch"
        return 0
    fi
    
    # Validate configuration
    if ! validate_ssh_config "$config_file"; then
        log_info "SSH keys configuration skipped"
        return 0
    fi
    
    # Get Windows user profile path
    log_info "Detecting Windows user profile..."
    local windows_profile
    if ! windows_profile=$(get_windows_user_profile); then
        log_error "Failed to get Windows user profile path"
        return 1
    fi
    log_info "Found Windows user profile: $windows_profile"
    
    # Skeleton configuration: Check if SSH keys exist before proceeding
    if ! check_ssh_keys_exist "$config_file" "$windows_profile"; then
        log_info "SSH keys configuration skipped - no SSH keys found in Windows profile"
        return 0
    fi
    
    # Setup SSH directory structure
    if ! setup_ssh_directory; then
        log_error "Failed to setup SSH directory"
        return 1
    fi
    
    # Create SSH key symlinks
    if ! create_ssh_key_symlinks "$config_file" "$windows_profile"; then
        log_error "Failed to create SSH key symlinks"
        return 1
    fi
    
    # Generate SSH config
    if ! generate_ssh_config "$config_file"; then
        log_error "Failed to generate SSH config"
        return 1
    fi
    
    # Configure SSH agent
    if ! configure_ssh_agent "$config_file"; then
        log_error "Failed to configure SSH agent"
        return 1
    fi
    
    log_success "SSH keys configuration completed successfully"
    return 0
}

# Function to install SSH keys skeleton system for new users
install_ssh_keys_skeleton_system() {
    local config_file="$1"
    
    log_info "Installing SSH keys skeleton system for new users"
    
    # Only proceed if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "Cannot install skeleton system: no sudo access (this is expected for regular users)"
        return 0
    fi
    
    # Execute the skeleton installation script
    local skeleton_script="$SCRIPT_DIR/ssh-keys-skeleton.sh"
    if [[ -f "$skeleton_script" ]]; then
        log_info "Installing SSH keys skeleton system using $skeleton_script"
        bash "$skeleton_script" "install-system" "$config_file"
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_success "SSH keys skeleton system installed successfully"
            log_info "New users will automatically have SSH keys configured if they exist in Windows profile"
        else
            log_warn "SSH keys skeleton system installation completed with warnings"
        fi
        
        return $exit_code
    else
        log_error "SSH keys skeleton script not found at $skeleton_script"
        return 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
