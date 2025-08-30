#!/bin/bash

# test-framework.sh - Test script for the new installation framework

set -e

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(cd "$SCRIPT_DIR/../utils" && pwd)"

# Source the framework
source "$UTILS_DIR/installation-framework.sh"
source "$UTILS_DIR/security-helpers.sh"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=()

# Function to run a test
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo "Running test: $test_name"
    
    if $test_function; then
        echo "✅ PASS: $test_name"
        TEST_RESULTS+=("✅ $test_name")
        ((TESTS_PASSED++))
    else
        echo "❌ FAIL: $test_name"
        TEST_RESULTS+=("❌ $test_name")
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Test initialize_script function
test_initialize_script() {
    if initialize_script "test-software" "Test Software Description"; then
        # Check if environment variables are set
        if [ "$INSTALL_SCRIPT_NAME" = "test-software" ] && \
           [ "$INSTALL_SOFTWARE_DESCRIPTION" = "Test Software Description" ] && \
           [ -n "$INSTALL_SCRIPT_DIR" ]; then
            return 0
        fi
    fi
    return 1
}

# Test validate_url function
test_validate_url() {
    # Valid URLs
    if validate_url "https://github.com/test/repo" && \
       validate_url "http://example.com/path" && \
       validate_url "https://api.github.com/repos/owner/repo/releases/latest"; then
        
        # Invalid URLs should fail
        if ! validate_url "invalid-url" && \
           ! validate_url "ftp://example.com" && \
           ! validate_url ""; then
            return 0
        fi
    fi
    return 1
}

# Test validate_version_format function
test_validate_version_format() {
    # Valid versions
    if validate_version_format "1.2.3" && \
       validate_version_format "v1.2.3" && \
       validate_version_format "1.2.3-alpha" && \
       validate_version_format "latest"; then
        
        # Invalid versions should fail
        if ! validate_version_format ""; then
            return 0
        fi
    fi
    return 1
}

# Test validate_architecture function
test_validate_architecture() {
    # Valid architectures
    if validate_architecture "amd64" && \
       validate_architecture "arm64" && \
       validate_architecture "x86_64"; then
        
        # Invalid architecture should fail
        if ! validate_architecture "invalid-arch"; then
            return 0
        fi
    fi
    return 1
}

# Test sanitize_input function
test_sanitize_input() {
    local input="test-input_with.dots/and/slashes"
    local expected="test-input_with.dots/and/slashes"
    local result
    result=$(sanitize_input "$input")
    
    if [ "$result" = "$expected" ]; then
        # Test with dangerous characters
        local dangerous_input="test; rm -rf /"
        local safe_result
        safe_result=$(sanitize_input "$dangerous_input")
        
        # Should remove dangerous characters
        if [ "$safe_result" = "test" ]; then
            return 0
        fi
    fi
    return 1
}

# Test create_temp_file function
test_create_temp_file() {
    local temp_file
    temp_file=$(create_temp_file "test")
    
    if [ -n "$temp_file" ] && [ -f "$temp_file" ]; then
        # Clean up
        rm -f "$temp_file"
        return 0
    fi
    return 1
}

# Test get_system_architecture function
test_get_system_architecture() {
    local arch
    arch=$(get_system_architecture)
    
    # Should return a valid architecture
    if validate_architecture "$arch"; then
        return 0
    fi
    return 1
}

# Test security helpers
test_validate_and_sanitize_url() {
    # Valid URL
    local result
    result=$(validate_and_sanitize_url "https://github.com/test/repo" 2>/dev/null)
    
    if [ "$result" = "https://github.com/test/repo" ]; then
        # Invalid URL should fail
        if ! validate_and_sanitize_url "javascript:alert('xss')" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Test validate_file_path function
test_validate_file_path() {
    # Valid absolute path
    local result
    result=$(validate_file_path "/usr/local/bin/test" 2>/dev/null)
    
    if [ "$result" = "/usr/local/bin/test" ]; then
        # Relative path should fail when not allowed
        if ! validate_file_path "relative/path" false >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Test validate_command_name function
test_validate_command_name() {
    # Valid command names
    local result
    result=$(validate_command_name "docker" 2>/dev/null)
    
    if [ "$result" = "docker" ]; then
        # Invalid command name should fail
        if ! validate_command_name "invalid;command" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Test create_secure_temp_dir function
test_create_secure_temp_dir() {
    local temp_dir
    temp_dir=$(create_secure_temp_dir "test")
    
    if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
        # Check permissions (should be 700)
        local perms
        perms=$(stat -c "%a" "$temp_dir")
        
        # Clean up
        rm -rf "$temp_dir"
        
        if [ "$perms" = "700" ]; then
            return 0
        fi
    fi
    return 1
}

# Main test execution
echo "======================================="
echo "Installation Framework Test Suite"
echo "======================================="
echo ""

# Run all tests
run_test "initialize_script" test_initialize_script
run_test "validate_url" test_validate_url
run_test "validate_version_format" test_validate_version_format
run_test "validate_architecture" test_validate_architecture
run_test "sanitize_input" test_sanitize_input
run_test "create_temp_file" test_create_temp_file
run_test "get_system_architecture" test_get_system_architecture
run_test "validate_and_sanitize_url" test_validate_and_sanitize_url
run_test "validate_file_path" test_validate_file_path
run_test "validate_command_name" test_validate_command_name
run_test "create_secure_temp_dir" test_create_secure_temp_dir

# Show results
echo "======================================="
echo "Test Results"
echo "======================================="

for result in "${TEST_RESULTS[@]}"; do
    echo "$result"
done

echo ""
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "Total tests: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo "🎉 All tests passed!"
    exit 0
else
    echo ""
    echo "❌ Some tests failed!"
    exit 1
fi
