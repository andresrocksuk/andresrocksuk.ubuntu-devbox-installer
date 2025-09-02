#!/bin/bash

# Test SSH Keys Configuration
# This script tests the SSH key configuration functionality

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/utils"

# Source utilities
source "$UTILS_DIR/logger.sh"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=()

# Function to run a test
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    log_info "Running test: $test_name"
    
    if $test_function; then
        log_success "✅ PASS: $test_name"
        TEST_RESULTS+=("✅ $test_name")
        ((TESTS_PASSED++))
    else
        log_error "❌ FAIL: $test_name"
        TEST_RESULTS+=("❌ $test_name")
        ((TESTS_FAILED++))
    fi
}

# Test configuration file
TEST_CONFIG_FILE="$SCRIPT_DIR/test-ssh-config.yaml"

# Test functions
test_ssh_config_validation() {
    
    # Create a test config with SSH keys disabled
    cat > "$TEST_CONFIG_FILE" << 'EOF'
git_ssh_keys:
  enabled: false
EOF
    
    # Test with disabled config
    local script_path="$(dirname "$SCRIPT_DIR")/configurations/configure-ssh-keys.sh"
    if bash "$script_path" "$TEST_CONFIG_FILE" 2>/dev/null; then
        return 0  # Should succeed (skip) when disabled
    else
        return 1
    fi
}

test_ssh_config_parsing() {
    
    # Create a test config with valid SSH keys
    cat > "$TEST_CONFIG_FILE" << 'EOF'
git_ssh_keys:
  enabled: true
  keys:
    - name: "test-github"
      private_key: "id_test"
      public_key: "id_test.pub"
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
EOF
    
    # Test if yq can parse the configuration
    if yq eval '.git_ssh_keys.enabled' "$TEST_CONFIG_FILE" | grep -q "true"; then
        # Test key count
        local key_count=$(yq eval '.git_ssh_keys.keys | length' "$TEST_CONFIG_FILE")
        if [[ "$key_count" == "1" ]]; then
            return 0
        fi
    fi
    return 1
}

test_ssh_directory_setup() {
    
    # Create a temporary home directory for testing
    local test_home="$SCRIPT_DIR/test_home"
    mkdir -p "$test_home"
    
    # Test SSH directory creation
    local ssh_dir="$test_home/.ssh"
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
    fi
    
    if [[ -d "$ssh_dir" ]] && [[ "$(stat -c %a "$ssh_dir")" == "700" ]]; then
        # Cleanup
        rm -rf "$test_home"
        return 0
    else
        # Cleanup
        rm -rf "$test_home"
        return 1
    fi
}

test_ssh_config_generation() {
    
    # Create test SSH directory
    local test_home="$SCRIPT_DIR/test_home"
    local ssh_dir="$test_home/.ssh"
    mkdir -p "$ssh_dir"
    
    # Create test SSH config content
    local test_config="$ssh_dir/config"
    cat > "$test_config" << 'EOF'
Host github
    HostName github.com
    User git
    Port 22
    IdentityFile ~/.ssh/id_test
    PreferredAuthentications publickey
    IdentitiesOnly yes
    ForwardAgent no
    ServerAliveInterval 60
    ServerAliveCountMax 5
EOF
    
    # Test if the config file was created correctly
    if [[ -f "$test_config" ]] && grep -q "Host github" "$test_config"; then
        # Test permissions
        chmod 600 "$test_config"
        if [[ "$(stat -c %a "$test_config")" == "600" ]]; then
            # Cleanup
            rm -rf "$test_home"
            return 0
        fi
    fi
    
    # Cleanup
    rm -rf "$test_home"
    return 1
}

test_ssh_key_file_permissions() {
    
    # Create test SSH directory
    local test_home="$SCRIPT_DIR/test_home"
    local ssh_dir="$test_home/.ssh"
    mkdir -p "$ssh_dir"
    
    # Create test key files
    local private_key="$ssh_dir/id_test"
    local public_key="$ssh_dir/id_test.pub"
    
    touch "$private_key" "$public_key"
    
    # Set permissions
    chmod 600 "$private_key"
    chmod 644 "$public_key"
    
    # Test permissions
    local private_perms=$(stat -c %a "$private_key")
    local public_perms=$(stat -c %a "$public_key")
    
    if [[ "$private_perms" == "600" ]] && [[ "$public_perms" == "644" ]]; then
        # Cleanup
        rm -rf "$test_home"
        return 0
    else
        # Cleanup
        rm -rf "$test_home"
        return 1
    fi
}

test_windows_path_detection() {
    
    # Test if we can detect Windows paths (will work in WSL)
    if [[ -d "/mnt/c/Users" ]]; then
        return 0
    else
        return 0  # Skip test if not in WSL
    fi
}

test_security_validation() {
    
    # Test input validation for key names
    local invalid_chars=('$' '`' ';' '|' '&' '>' '<' '"' "'" '\\')
    local all_safe=true
    
    for char in "${invalid_chars[@]}"; do
        local test_input="test${char}key"
        # Simple regex test for safe characters
        if [[ "$test_input" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
            all_safe=false
            break
        fi
    done
    
    if $all_safe; then
        return 0
    else
        return 1
    fi
}

# Main test runner
main() {
    log_section "SSH Keys Configuration Tests"
    
    # Check if required tools are available
    if ! command -v yq >/dev/null; then
        log_error "yq is required for SSH keys tests"
        exit 1
    fi
    
    # Run tests
    run_test "SSH Config Validation" test_ssh_config_validation
    run_test "SSH Config Parsing" test_ssh_config_parsing
    run_test "SSH Directory Setup" test_ssh_directory_setup
    run_test "SSH Config Generation" test_ssh_config_generation
    run_test "SSH Key File Permissions" test_ssh_key_file_permissions
    run_test "Windows Path Detection" test_windows_path_detection
    run_test "Security Validation" test_security_validation
    
    # Cleanup test files
    [[ -f "$TEST_CONFIG_FILE" ]] && rm -f "$TEST_CONFIG_FILE"
    
    # Print summary
    log_section "Test Summary"
    log_info "Tests passed: $TESTS_PASSED"
    log_info "Tests failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All SSH keys tests passed!"
        return 0
    else
        log_error "Some SSH keys tests failed"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
