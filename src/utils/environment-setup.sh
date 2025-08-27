#!/bin/bash

# Common environment setup functions for all installation scripts
# This file provides reusable functions for setting up PATH and environment variables

# Function to add a directory to PATH in shell profile files
add_to_path() {
    local bin_dir="$1"
    local profile_comment="${2:-Added by installation script}"
    
    if [ -z "$bin_dir" ]; then
        echo "Error: No binary directory provided to add_to_path"
        return 1
    fi
    
    # Add to current session
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        export PATH="$bin_dir:$PATH"
    fi
    
    # List of shell profile files to update
    local profiles=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.profile"
    )
    
    # Update user's shell profiles
    for profile in "${profiles[@]}"; do
        if [ -f "$profile" ]; then
            if ! grep -q "$bin_dir" "$profile" 2>/dev/null; then
                echo "" >> "$profile"
                echo "# $profile_comment" >> "$profile"
                echo "export PATH=\"$bin_dir:\$PATH\"" >> "$profile"
                echo "Added PATH configuration to $profile"
            else
                echo "PATH already configured in $profile"
            fi
        fi
    done
}

# Function to add environment variable to shell profiles
add_environment_var() {
    local var_name="$1"
    local var_value="$2"
    local profile_comment="${3:-Added by installation script}"
    
    if [ -z "$var_name" ] || [ -z "$var_value" ]; then
        echo "Error: Variable name and value required for add_environment_var"
        return 1
    fi
    
    # Export for current session
    export "$var_name"="$var_value"
    
    # List of shell profile files to update
    local profiles=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.profile"
    )
    
    # Update user's shell profiles
    for profile in "${profiles[@]}"; do
        if [ -f "$profile" ]; then
            if ! grep -q "export $var_name=" "$profile" 2>/dev/null; then
                echo "" >> "$profile"
                echo "# $profile_comment" >> "$profile"
                echo "export $var_name=\"$var_value\"" >> "$profile"
                echo "Added $var_name to $profile"
            else
                echo "$var_name already configured in $profile"
            fi
        fi
    done
}

# Function to source a script in shell profiles
source_script_in_profiles() {
    local script_path="$1"
    local profile_comment="${2:-Added by installation script}"
    
    if [ -z "$script_path" ]; then
        echo "Error: Script path required for source_script_in_profiles"
        return 1
    fi
    
    if [ ! -f "$script_path" ]; then
        echo "Warning: Script $script_path does not exist"
        return 1
    fi
    
    # Source for current session
    source "$script_path" 2>/dev/null || true
    
    # List of shell profile files to update
    local profiles=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
    )
    
    # Update user's shell profiles
    for profile in "${profiles[@]}"; do
        if [ -f "$profile" ]; then
            if ! grep -q "source.*$(basename "$script_path")" "$profile" 2>/dev/null; then
                echo "" >> "$profile"
                echo "# $profile_comment" >> "$profile"
                echo "[ -f \"$script_path\" ] && source \"$script_path\"" >> "$profile"
                echo "Added source configuration to $profile"
            else
                echo "Source already configured in $profile"
            fi
        fi
    done
}

# Function to create system-wide environment configuration
setup_system_wide_env() {
    local config_name="$1"
    local config_content="$2"
    
    if [ -z "$config_name" ] || [ -z "$config_content" ]; then
        echo "Error: Config name and content required for setup_system_wide_env"
        return 1
    fi
    
    # Create system-wide environment file
    local env_file="/etc/environment.d/${config_name}.conf"
    
    if [ -w /etc/environment.d ] || sudo -n true 2>/dev/null; then
        echo "Setting up system-wide environment configuration: $env_file"
        echo "$config_content" | sudo tee "$env_file" > /dev/null
        return 0
    else
        echo "Warning: Cannot create system-wide environment file (no sudo access)"
        return 1
    fi
}

# Function to update skeleton files for new users
update_skeleton_files() {
    local config_content="$1"
    local profile_comment="${2:-Added by installation script}"
    
    if [ -z "$config_content" ]; then
        echo "Error: Config content required for update_skeleton_files"
        return 1
    fi
    
    # Only proceed if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        echo "Warning: Cannot update skeleton files (no sudo access)"
        return 1
    fi
    
    echo "Updating skeleton files for new users..."
    
    # IMPORTANT: Only update bash/profile files, never .zshrc
    # zsh configurations should use the modular approach with /usr/local/share/*/
    local skel_files=(
        "/etc/skel/.bashrc"
        "/etc/skel/.profile"
    )
    
    for skel_file in "${skel_files[@]}"; do
        if [ -f "$skel_file" ]; then
            # Check if configuration already exists
            if ! sudo grep -q "$profile_comment" "$skel_file" 2>/dev/null; then
                echo "" | sudo tee -a "$skel_file" > /dev/null
                echo "# $profile_comment" | sudo tee -a "$skel_file" > /dev/null
                echo "$config_content" | sudo tee -a "$skel_file" > /dev/null
                echo "Updated $skel_file"
            else
                echo "Configuration already exists in $skel_file"
            fi
        else
            # Create skeleton file if it doesn't exist
            echo "Creating $skel_file"
            sudo mkdir -p "$(dirname "$skel_file")"
            echo "# $profile_comment" | sudo tee "$skel_file" > /dev/null
            echo "$config_content" | sudo tee -a "$skel_file" > /dev/null
        fi
    done
    
    echo "Note: .zshrc skeleton managed separately by zsh configuration system"
}

# Function to install binary to system-wide location
install_binary_system_wide() {
    local binary_path="$1"
    local binary_name="${2:-$(basename "$binary_path")}"
    local target_dir="${3:-/usr/local/bin}"
    
    if [ -z "$binary_path" ] || [ ! -f "$binary_path" ]; then
        echo "Error: Binary path required and must exist for install_binary_system_wide"
        return 1
    fi
    
    # Only proceed if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        echo "Warning: Cannot install binary system-wide (no sudo access)"
        return 1
    fi
    
    echo "Installing $binary_name to $target_dir"
    sudo mkdir -p "$target_dir"
    sudo cp "$binary_path" "$target_dir/$binary_name"
    sudo chmod +x "$target_dir/$binary_name"
    
    echo "Binary installed to $target_dir/$binary_name"
    return 0
}

# Function to verify environment setup
verify_environment_setup() {
    local command_name="$1"
    local expected_path="$2"
    
    if [ -z "$command_name" ]; then
        echo "Error: Command name required for verify_environment_setup"
        return 1
    fi
    
    echo "Verifying environment setup for $command_name..."
    
    # Check if command is available
    if command -v "$command_name" >/dev/null 2>&1; then
        local found_path=$(which "$command_name")
        echo "✓ $command_name found at: $found_path"
        
        if [ -n "$expected_path" ] && [ "$found_path" != "$expected_path" ]; then
            echo "! Note: Found at different path than expected ($expected_path)"
        fi
        
        return 0
    else
        echo "✗ $command_name not found in PATH"
        
        if [ -n "$expected_path" ] && [ -f "$expected_path" ]; then
            echo "! $command_name exists at $expected_path but not in PATH"
        fi
        
        return 1
    fi
}
