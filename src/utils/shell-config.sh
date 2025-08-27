#!/bin/bash

# shell-config.sh - Utility functions for managing shell configurations
# This script provides functions to safely add PATH and environment variables
# to shell configuration files, handling Oh-My-Zsh .zshrc.local pattern

# Function to add configuration to a shell profile
# Usage: add_to_shell_profile <profile_file> <config_content> <identifier>
add_to_shell_profile() {
    local profile_file="$1"
    local config_content="$2"
    local identifier="$3"
    
    if [ ! -f "$profile_file" ]; then
        return 1
    fi
    
    # Check if configuration already exists
    if grep -q "$identifier" "$profile_file"; then
        return 0
    fi
    
    # Add configuration
    echo "" >> "$profile_file"
    echo "$config_content" >> "$profile_file"
    return 0
}

# Function to add PATH export to bash and zsh profiles
# Usage: add_path_to_profiles <path_export> <comment> <identifier>
add_path_to_profiles() {
    local path_export="$1"
    local comment="$2"
    local identifier="$3"
    
    local config_block=""
    if [ -n "$comment" ]; then
        config_block="# $comment"$'\n'
    fi
    config_block+="$path_export"
    
    # Add to .bashrc if it exists
    if [ -f ~/.bashrc ]; then
        if ! grep -q "$identifier" ~/.bashrc; then
            add_to_shell_profile ~/.bashrc "$config_block" "$identifier"
            log_info "Added $comment to ~/.bashrc"
        fi
    fi
    
    # Handle zsh configuration
    if [ -f ~/.zshrc ]; then
        # Check if using Oh-My-Zsh (which supports .zshrc.local)
        if grep -q "oh-my-zsh" ~/.zshrc; then
            # Use .zshrc.local for Oh-My-Zsh
            local zsh_config_file="$HOME/.zshrc.local"
            touch "$zsh_config_file"
            if ! grep -q "$identifier" "$zsh_config_file"; then
                add_to_shell_profile "$zsh_config_file" "$config_block" "$identifier"
                log_info "Added $comment to ~/.zshrc.local (Oh-My-Zsh)"
            fi
        else
            # Add directly to .zshrc if not using Oh-My-Zsh
            if ! grep -q "$identifier" ~/.zshrc; then
                add_to_shell_profile ~/.zshrc "$config_block" "$identifier"
                log_info "Added $comment to ~/.zshrc"
            fi
        fi
    fi
    
    # Add to .profile as fallback
    if [ -f ~/.profile ]; then
        if ! grep -q "$identifier" ~/.profile; then
            add_to_shell_profile ~/.profile "$config_block" "$identifier"
            log_info "Added $comment to ~/.profile"
        fi
    fi
}

# Function to add environment variables to profiles
# Usage: add_env_to_profiles <env_exports> <comment> <identifier>
add_env_to_profiles() {
    local env_exports="$1"
    local comment="$2"
    local identifier="$3"
    
    local config_block=""
    if [ -n "$comment" ]; then
        config_block="# $comment"$'\n'
    fi
    config_block+="$env_exports"
    
    # Add to .bashrc if it exists
    if [ -f ~/.bashrc ]; then
        if ! grep -q "$identifier" ~/.bashrc; then
            add_to_shell_profile ~/.bashrc "$config_block" "$identifier"
            log_info "Added $comment environment to ~/.bashrc"
        fi
    fi
    
    # Handle zsh configuration
    if [ -f ~/.zshrc ]; then
        # Check if using Oh-My-Zsh
        if grep -q "oh-my-zsh" ~/.zshrc; then
            # Use .zshrc.local for Oh-My-Zsh
            local zsh_config_file="$HOME/.zshrc.local"
            touch "$zsh_config_file"
            if ! grep -q "$identifier" "$zsh_config_file"; then
                add_to_shell_profile "$zsh_config_file" "$config_block" "$identifier"
                log_info "Added $comment environment to ~/.zshrc.local (Oh-My-Zsh)"
            fi
        else
            # Add directly to .zshrc if not using Oh-My-Zsh
            if ! grep -q "$identifier" ~/.zshrc; then
                add_to_shell_profile ~/.zshrc "$config_block" "$identifier"
                log_info "Added $comment environment to ~/.zshrc"
            fi
        fi
    fi
}

# Function to fix existing PATH configurations that were lost during Oh-My-Zsh setup
fix_existing_path_configs() {
    log_info "Checking and fixing existing PATH configurations..."
    
    # Check for Node.js npm global path in .bashrc but missing from zsh
    if grep -q "npm-global" ~/.bashrc && [ -f ~/.zshrc ]; then
        if grep -q "oh-my-zsh" ~/.zshrc; then
            local zsh_config_file="$HOME/.zshrc.local"
            if ! grep -q "npm-global" "$zsh_config_file" 2>/dev/null; then
                touch "$zsh_config_file"
                echo "" >> "$zsh_config_file"
                echo "# npm global packages" >> "$zsh_config_file"
                echo "export PATH=~/.npm-global/bin:\$PATH" >> "$zsh_config_file"
                log_info "Fixed npm global path in ~/.zshrc.local"
            fi
        fi
    fi
    
    # Check for Go path in .bashrc but missing from zsh
    if grep -q "/usr/local/go/bin" ~/.bashrc && [ -f ~/.zshrc ]; then
        if grep -q "oh-my-zsh" ~/.zshrc; then
            local zsh_config_file="$HOME/.zshrc.local"
            if ! grep -q "/usr/local/go/bin" "$zsh_config_file" 2>/dev/null; then
                touch "$zsh_config_file"
                echo "" >> "$zsh_config_file"
                echo "# Go programming language" >> "$zsh_config_file"
                echo "export PATH=\$PATH:/usr/local/go/bin" >> "$zsh_config_file"
                log_info "Fixed Go path in ~/.zshrc.local"
            fi
        fi
    fi
    
    # Check for GOPATH configuration
    if grep -q "GOPATH" ~/.bashrc && [ -f ~/.zshrc ]; then
        if grep -q "oh-my-zsh" ~/.zshrc; then
            local zsh_config_file="$HOME/.zshrc.local"
            if ! grep -q "GOPATH" "$zsh_config_file" 2>/dev/null; then
                touch "$zsh_config_file"
                echo "" >> "$zsh_config_file"
                echo "# Go environment" >> "$zsh_config_file"
                echo "export GOPATH=\$HOME/go" >> "$zsh_config_file"
                echo "export GOBIN=\$GOPATH/bin" >> "$zsh_config_file"
                echo "export PATH=\$PATH:\$GOBIN" >> "$zsh_config_file"
                log_info "Fixed Go environment in ~/.zshrc.local"
            fi
        fi
    fi
}
