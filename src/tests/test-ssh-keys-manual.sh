#!/bin/bash

# Manual Testing Guide for Git SSH Keys Feature
# This script helps create a test environment for validating SSH keys functionality

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/utils"

# Source utilities
source "$UTILS_DIR/logger.sh"

# Test configuration
TEST_HOME="$SCRIPT_DIR/test_environment"
TEST_WINDOWS_SSH="$TEST_HOME/windows_ssh"
TEST_WSL_HOME="$TEST_HOME/wsl_home"
TEST_CONFIG="$TEST_HOME/test-ssh-config.yaml"

log_section "Git SSH Keys Manual Testing Setup"

# Function to create test environment
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Clean up any existing test environment
    rm -rf "$TEST_HOME"
    
    # Create directory structure
    mkdir -p "$TEST_WINDOWS_SSH"
    mkdir -p "$TEST_WSL_HOME/.ssh"
    
    # Create test SSH keys
    log_info "Creating test SSH keys..."
    
    # Generate Ed25519 key pair
    ssh-keygen -t ed25519 -f "$TEST_WINDOWS_SSH/id_ed25519" -N "" -C "test@example.com"
    
    # Generate RSA key pair for GitLab example
    ssh-keygen -t rsa -b 4096 -f "$TEST_WINDOWS_SSH/id_rsa_gitlab" -N "" -C "test-gitlab@example.com"
    
    log_success "Test SSH keys created:"
    log_info "  Ed25519: $TEST_WINDOWS_SSH/id_ed25519"
    log_info "  RSA:     $TEST_WINDOWS_SSH/id_rsa_gitlab"
}

# Function to create test configuration
create_test_config() {
    log_info "Creating test configuration..."
    
    cat > "$TEST_CONFIG" << 'EOF'
# Test Configuration for SSH Keys
metadata:
  name: "SSH Keys Test Environment"
  description: "Testing SSH key configuration"
  version: "1.0.0"

git_ssh_keys:
  enabled: true
  keys:
    - name: "github"
      private_key: "id_ed25519"
      public_key: "id_ed25519.pub"
      hosts:
        - name: "github"
          hostname: "github.com"
          user: "git"
          port: 22
          preferred_authentications: "publickey"
          identities_only: true
          forward_agent: false
          server_alive_interval: 60
          server_alive_count_max: 5
    - name: "gitlab"
      private_key: "id_rsa_gitlab"
      public_key: "id_rsa_gitlab.pub"
      hosts:
        - name: "gitlab"
          hostname: "gitlab.com"
          user: "git"
          port: 22
          preferred_authentications: "publickey"
          identities_only: true
          forward_agent: false
          server_alive_interval: 60
          server_alive_count_max: 5
EOF
    
    log_success "Test configuration created: $TEST_CONFIG"
}

# Function to test SSH configuration script
test_ssh_configuration() {
    log_info "Testing SSH configuration script..."
    
    # Set environment variables to override paths for testing
    export HOME="$TEST_WSL_HOME"
    
    # Create a modified version of the SSH script for testing
    local test_script="$TEST_HOME/test-configure-ssh-keys.sh"
    
    # Copy the original script and modify it for testing
    cp "$(dirname "$SCRIPT_DIR")/configurations/configure-ssh-keys.sh" "$test_script"
    
    # Modify the get_windows_user_profile function for testing
    sed -i "s|get_windows_user_profile() {|get_windows_user_profile() {
    echo \"$TEST_WINDOWS_SSH\"
    return 0
}

get_windows_user_profile_original() {|" "$test_script"
    
    # Make the test script executable
    chmod +x "$test_script"
    
    # Run the SSH configuration script with test config
    if bash "$test_script" "$TEST_CONFIG"; then
        log_success "SSH configuration script completed successfully"
        return 0
    else
        log_error "SSH configuration script failed"
        return 1
    fi
}

# Function to validate results
validate_test_results() {
    log_info "Validating test results..."
    
    local ssh_dir="$TEST_WSL_HOME/.ssh"
    local success=0
    
    # Check if symlinks were created
    log_info "Checking symlinks..."
    if [[ -L "$ssh_dir/id_ed25519" ]] && [[ -L "$ssh_dir/id_ed25519.pub" ]]; then
        log_success "✅ Ed25519 key symlinks created"
    else
        log_error "❌ Ed25519 key symlinks missing"
        ((success++))
    fi
    
    if [[ -L "$ssh_dir/id_rsa_gitlab" ]] && [[ -L "$ssh_dir/id_rsa_gitlab.pub" ]]; then
        log_success "✅ RSA GitLab key symlinks created"
    else
        log_error "❌ RSA GitLab key symlinks missing"
        ((success++))
    fi
    
    # Check permissions
    log_info "Checking file permissions..."
    if [[ -f "$ssh_dir/id_ed25519" ]]; then
        local perms=$(stat -c %a "$ssh_dir/id_ed25519")
        if [[ "$perms" == "600" ]]; then
            log_success "✅ Private key permissions correct (600)"
        else
            log_error "❌ Private key permissions incorrect: $perms (expected 600)"
            ((success++))
        fi
    fi
    
    if [[ -f "$ssh_dir/id_ed25519.pub" ]]; then
        local perms=$(stat -c %a "$ssh_dir/id_ed25519.pub")
        if [[ "$perms" == "644" ]]; then
            log_success "✅ Public key permissions correct (644)"
        else
            log_error "❌ Public key permissions incorrect: $perms (expected 644)"
            ((success++))
        fi
    fi
    
    # Check SSH config file
    log_info "Checking SSH config file..."
    if [[ -f "$ssh_dir/config" ]]; then
        log_success "✅ SSH config file created"
        
        # Check for GitHub host configuration
        if grep -q "Host github" "$ssh_dir/config"; then
            log_success "✅ GitHub host configuration found"
        else
            log_error "❌ GitHub host configuration missing"
            ((success++))
        fi
        
        # Check for GitLab host configuration
        if grep -q "Host gitlab" "$ssh_dir/config"; then
            log_success "✅ GitLab host configuration found"
        else
            log_error "❌ GitLab host configuration missing"
            ((success++))
        fi
        
        # Show the generated config
        log_info "Generated SSH config:"
        echo "----------------------------------------"
        cat "$ssh_dir/config"
        echo "----------------------------------------"
    else
        log_error "❌ SSH config file not created"
        ((success++))
    fi
    
    return $success
}

# Function to test with real Windows SSH directory (if available)
test_with_real_windows_ssh() {
    log_info "Testing with real Windows SSH directory (if available)..."
    
    local windows_ssh="/mnt/c/Users/$USER/.ssh"
    if [[ -d "$windows_ssh" ]]; then
        log_info "Found Windows SSH directory: $windows_ssh"
        
        # List available keys
        log_info "Available SSH keys in Windows:"
        ls -la "$windows_ssh" | grep -E '\.(pub|key|pem)$' || log_info "No SSH keys found"
        
        # Test with actual SSH script
        local actual_script="$(dirname "$SCRIPT_DIR")/configurations/configure-ssh-keys.sh"
        log_info "Testing with actual SSH configuration script..."
        
        # Create a backup of current SSH config if it exists
        if [[ -f "$HOME/.ssh/config" ]]; then
            cp "$HOME/.ssh/config" "$HOME/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)"
            log_info "Backed up existing SSH config"
        fi
        
        # Run with the main config profile (which has SSH keys enabled but may not have real keys)
        log_info "Running with main configuration profile (may fail if keys don't exist - this is expected)..."
        bash "$actual_script" "$(dirname "$SCRIPT_DIR")/config-profiles/full-install.yaml" || log_info "Script completed (may have failed due to missing keys)"
    else
        log_info "No Windows SSH directory found at $windows_ssh"
        log_info "This is normal if you don't have SSH keys set up in Windows"
    fi
}

# Function to cleanup test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    rm -rf "$TEST_HOME"
    log_success "Test environment cleaned up"
}

# Function to show manual testing instructions
show_manual_testing_instructions() {
    log_section "Manual Testing Instructions"
    
    echo "To fully test the SSH keys feature with real keys:"
    echo ""
    echo "1. **Setup SSH Keys in Windows:**"
    echo "   - Open PowerShell as Administrator"
    echo "   - Generate SSH keys: ssh-keygen -t ed25519 -f \$env:USERPROFILE\\.ssh\\id_ed25519"
    echo "   - Ensure keys exist in %USERPROFILE%\\.ssh\\"
    echo ""
    echo "2. **Update Configuration:**"
    echo "   - Edit src/config-profiles/full-install.yaml (or your chosen profile)"
    echo "   - Set git_ssh_keys.enabled: true"
    echo "   - Configure your key names and host settings"
    echo ""
    echo "3. **Test Full Installation:**"
    echo "   - Run: ./install-wsl.ps1 -AutoInstall -Sections configurations"
    echo "   - Check: ls -la ~/.ssh/"
    echo "   - Verify: cat ~/.ssh/config"
    echo "   - Test: ssh -T git@github.com (if configured for GitHub)"
    echo ""
    echo "4. **Test SSH Agent:**"
    echo "   - Run: ssh-add -l"
    echo "   - Should show loaded keys"
    echo ""
    echo "5. **Test Git Operations:**"
    echo "   - Clone a private repository using SSH"
    echo "   - Verify authentication works without password prompts"
}

# Main function
main() {
    log_info "Starting Git SSH Keys manual testing..."
    
    # Setup test environment
    setup_test_environment
    create_test_config
    
    # Run tests
    if test_ssh_configuration; then
        log_success "SSH configuration test completed"
        
        if validate_test_results; then
            log_success "🎉 All validation tests passed!"
        else
            log_error "Some validation tests failed"
        fi
    else
        log_error "SSH configuration test failed"
    fi
    
    # Test with real Windows SSH if available
    test_with_real_windows_ssh
    
    # Show manual testing instructions
    show_manual_testing_instructions
    
    # Cleanup
    read -p "Press Enter to cleanup test environment..."
    cleanup_test_environment
    
    log_success "Testing complete!"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
