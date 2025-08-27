#!/bin/bash

# test-installation.sh - WSL installation verification script
# This script tests all installed software and generates a report

set -e

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../install.yaml"
UTILS_DIR="$SCRIPT_DIR/../utils"

# Generate unique run ID for this execution if not already set
# (it might be set if this is called from install.sh)
if [ -z "$WSL_INSTALL_RUN_ID" ]; then
    export WSL_INSTALL_RUN_ID="$(date +%Y%m%d_%H%M%S)"
fi

# Set log directory before sourcing logger
export LOG_DIR="$SCRIPT_DIR/../logs"

# Source utilities
source "$UTILS_DIR/logger.sh"
source "$UTILS_DIR/version-checker.sh"

# Global variables
TEST_RESULTS=()
FAILED_TESTS=()
MISSING_SOFTWARE=()
VERSION_MISMATCHES=()
GENERATE_REPORT=false
TEST_SPECIFIC_SOFTWARE=""

# Function to display help
show_help() {
    cat << EOF
WSL Installation Test Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -r, --report        Generate detailed report file
    -s, --software      Test specific software (comma-separated list)
    -l, --log-level     Set log level (DEBUG, INFO, WARN, ERROR)
    -v, --version       Show script version

Examples:
    $0                      # Test all installed software
    $0 --report             # Test and generate detailed report
    $0 --software "git,python3,node"  # Test specific software only
    $0 --log-level DEBUG    # Enable debug logging

EOF
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -r|--report)
                GENERATE_REPORT=true
                shift
                ;;
            -s|--software)
                TEST_SPECIFIC_SOFTWARE="$2"
                shift 2
                ;;
            -l|--log-level)
                set_log_level "$2"
                shift 2
                ;;
            -v|--version)
                echo "WSL Installation Test Script v1.0.0"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Function to ensure yq is available
ensure_yq() {
    if ! command_exists "yq"; then
        log_error "yq is required for testing but not installed"
        log_info "Please run the installation script first or install yq manually"
        exit 1
    fi
}

# Function to test a single command
test_command() {
    local software="$1"
    local command="${2:-$software}"
    local expected_version="${3:-any}"
    local version_flag="${4:---version}"
    
    log_debug "Testing $software..."
    
    local current_version
    current_version=$(get_command_version "$command" "$version_flag")
    
    if [ "$current_version" = "NOT_INSTALLED" ]; then
        MISSING_SOFTWARE+=("$software")
        log_error "❌ $software: not installed"
        return 1
    elif [ "$current_version" = "UNKNOWN" ]; then
        TEST_RESULTS+=("⚠️  $software: installed but version unknown")
        log_warn "⚠️  $software: installed but version unknown"
        return 0
    else
        if [ "$expected_version" != "any" ] && ! version_compare "$current_version" "$expected_version"; then
            VERSION_MISMATCHES+=("$software: expected $expected_version, got $current_version")
            log_warn "⚠️  $software: version mismatch (expected $expected_version, got $current_version)"
        else
            TEST_RESULTS+=("✅ $software: $current_version")
            log_success "✅ $software: $current_version"
        fi
        return 0
    fi
}

# Function to test Python packages
test_python_package() {
    local package="$1"
    local expected_version="${2:-any}"
    
    log_debug "Testing Python package: $package"
    
    if ! command_exists "python3"; then
        log_error "Python3 not available for testing $package"
        return 1
    fi
    
    local current_version
    current_version=$(python3 -c "import $package; print($package.__version__)" 2>/dev/null || echo "NOT_INSTALLED")
    
    if [ "$current_version" = "NOT_INSTALLED" ]; then
        MISSING_SOFTWARE+=("$package (Python)")
        log_error "❌ $package (Python): not installed"
        return 1
    else
        if [ "$expected_version" != "any" ] && ! version_compare "$current_version" "$expected_version"; then
            VERSION_MISMATCHES+=("$package (Python): expected $expected_version, got $current_version")
            log_warn "⚠️  $package (Python): version mismatch (expected $expected_version, got $current_version)"
        else
            TEST_RESULTS+=("✅ $package (Python): $current_version")
            log_success "✅ $package (Python): $current_version"
        fi
        return 0
    fi
}

# Function to test PowerShell modules
test_powershell_module() {
    local module="$1"
    local expected_version="${2:-any}"
    
    log_debug "Testing PowerShell module: $module"
    
    if ! command_exists "pwsh"; then
        log_error "PowerShell not available for testing $module"
        return 1
    fi
    
    local current_version
    current_version=$(pwsh -Command "try { (Get-Module -ListAvailable -Name '$module' | Select-Object -First 1).Version.ToString() } catch { 'NOT_INSTALLED' }" 2>/dev/null)
    
    if [ "$current_version" = "NOT_INSTALLED" ] || [ -z "$current_version" ]; then
        MISSING_SOFTWARE+=("$module (PowerShell)")
        log_error "❌ $module (PowerShell): not installed"
        return 1
    else
        if [ "$expected_version" != "any" ] && ! version_compare "$current_version" "$expected_version"; then
            VERSION_MISMATCHES+=("$module (PowerShell): expected $expected_version, got $current_version")
            log_warn "⚠️  $module (PowerShell): version mismatch (expected $expected_version, got $current_version)"
        else
            TEST_RESULTS+=("✅ $module (PowerShell): $current_version")
            log_success "✅ $module (PowerShell): $current_version"
        fi
        return 0
    fi
}

# Function to test APT packages
test_apt_packages() {
    log_section "Testing APT Packages"
    
    local apt_packages
    apt_packages=$(yq eval '.apt_packages | length' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$apt_packages" = "0" ] || [ "$apt_packages" = "null" ]; then
        log_info "No apt packages to test"
        return 0
    fi
    
    for i in $(seq 0 $((apt_packages - 1))); do
        local name=$(yq eval ".apt_packages[$i].name" "$CONFIG_FILE")
        local version=$(yq eval ".apt_packages[$i].version // \"any\"" "$CONFIG_FILE")
        local command=$(yq eval ".apt_packages[$i].command // \"$name\"" "$CONFIG_FILE")
        
        if [ -n "$name" ] && [ "$name" != "null" ]; then
            if should_test_software "$name"; then
                test_command "$name" "$command" "$version"
            fi
        fi
    done
}

# Function to test custom software
test_custom_software() {
    log_section "Testing Custom Software"
    
    local custom_software
    custom_software=$(yq eval '.custom_software | length' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$custom_software" = "0" ] || [ "$custom_software" = "null" ]; then
        log_info "No custom software to test"
        return 0
    fi
    
    for i in $(seq 0 $((custom_software - 1))); do
        local name=$(yq eval ".custom_software[$i].name" "$CONFIG_FILE")
        local version_command=$(yq eval ".custom_software[$i].version_command // \"$name\"" "$CONFIG_FILE")
        local version_flag=$(yq eval ".custom_software[$i].version_flag // \"--version\"" "$CONFIG_FILE")
        
        if [ -n "$name" ] && [ "$name" != "null" ]; then
            if should_test_software "$name"; then
                # Handle special cases
                case "$name" in
                    "nodejs-lts")
                        test_command "$name" "node" "any" "--version"
                        ;;
                    "oh-my-zsh")
                        if [ -d "$HOME/.oh-my-zsh" ]; then
                            TEST_RESULTS+=("✅ $name: installed")
                            log_success "✅ $name: installed"
                        else
                            MISSING_SOFTWARE+=("$name")
                            log_error "❌ $name: not installed"
                        fi
                        ;;
                    *)
                        test_command "$name" "$version_command" "any" "$version_flag"
                        ;;
                esac
            fi
        fi
    done
}

# Function to test Python packages
test_python_packages() {
    log_section "Testing Python Packages"
    
    local python_packages
    python_packages=$(yq eval '.python_packages | length' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$python_packages" = "0" ] || [ "$python_packages" = "null" ]; then
        log_info "No Python packages to test"
        return 0
    fi
    
    for i in $(seq 0 $((python_packages - 1))); do
        local name=$(yq eval ".python_packages[$i].name" "$CONFIG_FILE")
        local version=$(yq eval ".python_packages[$i].version // \"any\"" "$CONFIG_FILE")
        
        if [ -n "$name" ] && [ "$name" != "null" ]; then
            if should_test_software "$name"; then
                # Handle package name mapping
                local import_name="$name"
                case "$name" in
                    "pre-commit")
                        import_name="pre_commit"
                        ;;
                esac
                
                test_python_package "$import_name" "$version"
            fi
        fi
    done
}

# Function to test PowerShell modules
test_powershell_modules() {
    log_section "Testing PowerShell Modules"
    
    local powershell_modules
    powershell_modules=$(yq eval '.powershell_modules | length' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$powershell_modules" = "0" ] || [ "$powershell_modules" = "null" ]; then
        log_info "No PowerShell modules to test"
        return 0
    fi
    
    for i in $(seq 0 $((powershell_modules - 1))); do
        local name=$(yq eval ".powershell_modules[$i].name" "$CONFIG_FILE")
        local version=$(yq eval ".powershell_modules[$i].version // \"any\"" "$CONFIG_FILE")
        
        if [ -n "$name" ] && [ "$name" != "null" ]; then
            if should_test_software "$name"; then
                test_powershell_module "$name" "$version"
            fi
        fi
    done
}

# Function to test system configurations
test_configurations() {
    log_section "Testing Configurations"
    
    # Test shell configuration
    if [ "$SHELL" = "$(which zsh)" ]; then
        TEST_RESULTS+=("✅ Default shell: zsh")
        log_success "✅ Default shell: zsh"
    else
        TEST_RESULTS+=("⚠️  Default shell: $(basename "$SHELL") (expected zsh)")
        log_warn "⚠️  Default shell: $(basename "$SHELL") (expected zsh)"
    fi
    
    # Test oh-my-zsh installation
    if [ -d "$HOME/.oh-my-zsh" ]; then
        TEST_RESULTS+=("✅ oh-my-zsh: installed")
        log_success "✅ oh-my-zsh: installed"
    else
        MISSING_SOFTWARE+=("oh-my-zsh configuration")
        log_error "❌ oh-my-zsh: not installed"
    fi
    
    # Test neovim configuration
    if [ -f "$HOME/.config/nvim/init.vim" ]; then
        TEST_RESULTS+=("✅ Neovim config: present")
        log_success "✅ Neovim config: present"
    else
        TEST_RESULTS+=("⚠️  Neovim config: not found")
        log_warn "⚠️  Neovim config: not found"
    fi
}

# Function to check if software should be tested
should_test_software() {
    local software="$1"
    
    if [ -z "$TEST_SPECIFIC_SOFTWARE" ]; then
        return 0
    fi
    
    echo "$TEST_SPECIFIC_SOFTWARE" | grep -q "$software"
}

# Function to generate detailed report
generate_detailed_report() {
    if [ "$GENERATE_REPORT" != "true" ]; then
        return 0
    fi
    
    local report_file="$LOGS_DIR/test-results-$WSL_INSTALL_RUN_ID.txt"
    mkdir -p "$LOGS_DIR"
    
    log_info "Generating detailed report: $report_file"
    
    {
        echo "WSL Installation Test Report"
        echo "Generated: $(date)"
        if [ -n "$WSL_INSTALL_RUN_ID" ]; then
            echo "Run ID: $WSL_INSTALL_RUN_ID"
        fi
        echo "Test Script Version: 1.0.0"
        echo "Configuration File: $CONFIG_FILE"
        echo "==========================================="
        echo ""
        
        echo "SUMMARY"
        echo "-------"
        echo "Total tests: $((${#TEST_RESULTS[@]} + ${#FAILED_TESTS[@]} + ${#MISSING_SOFTWARE[@]}))"
        echo "Successful: ${#TEST_RESULTS[@]}"
        echo "Missing software: ${#MISSING_SOFTWARE[@]}"
        echo "Version mismatches: ${#VERSION_MISMATCHES[@]}"
        echo ""
        
        if [ ${#TEST_RESULTS[@]} -gt 0 ]; then
            echo "SUCCESSFUL TESTS"
            echo "----------------"
            for result in "${TEST_RESULTS[@]}"; do
                echo "$result"
            done
            echo ""
        fi
        
        if [ ${#MISSING_SOFTWARE[@]} -gt 0 ]; then
            echo "MISSING SOFTWARE"
            echo "----------------"
            for missing in "${MISSING_SOFTWARE[@]}"; do
                echo "❌ $missing"
            done
            echo ""
        fi
        
        if [ ${#VERSION_MISMATCHES[@]} -gt 0 ]; then
            echo "VERSION MISMATCHES"
            echo "------------------"
            for mismatch in "${VERSION_MISMATCHES[@]}"; do
                echo "⚠️  $mismatch"
            done
            echo ""
        fi
        
        echo "SYSTEM INFORMATION"
        echo "------------------"
        echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo "WSL Version: $(cat /proc/version | grep -o 'WSL[0-9]*' || echo "Unknown")"
        echo "Current User: $(whoami)"
        echo "Current Shell: $SHELL"
        echo ""
        
        echo "ENVIRONMENT PATHS"
        echo "-----------------"
        echo "PATH: $PATH"
        echo ""
        
        if command_exists "go"; then
            echo "GOPATH: $(go env GOPATH 2>/dev/null || echo "Not set")"
            echo "GOROOT: $(go env GOROOT 2>/dev/null || echo "Not set")"
            echo ""
        fi
        
        if command_exists "npm"; then
            echo "NPM prefix: $(npm config get prefix 2>/dev/null || echo "Not set")"
            echo ""
        fi
        
    } > "$report_file"
    
    log_success "Detailed report generated: $report_file"
}

# Function to show test summary
show_summary() {
    log_section "Test Summary"
    
    local total_tests=$((${#TEST_RESULTS[@]} + ${#MISSING_SOFTWARE[@]}))
    local successful=${#TEST_RESULTS[@]}
    local missing=${#MISSING_SOFTWARE[@]}
    local mismatches=${#VERSION_MISMATCHES[@]}
    
    log_info "Total software tested: $total_tests"
    log_info "Successfully installed: $successful"
    log_info "Missing software: $missing"
    log_info "Version mismatches: $mismatches"
    
    if [ $successful -gt 0 ]; then
        log_info ""
        log_info "✅ Working software:"
        for result in "${TEST_RESULTS[@]}"; do
            log_info "  $result"
        done
    fi
    
    if [ $missing -gt 0 ]; then
        log_info ""
        log_warn "❌ Missing software:"
        for missing_item in "${MISSING_SOFTWARE[@]}"; do
            log_warn "  $missing_item"
        done
    fi
    
    if [ $mismatches -gt 0 ]; then
        log_info ""
        log_warn "⚠️  Version mismatches:"
        for mismatch in "${VERSION_MISMATCHES[@]}"; do
            log_warn "  $mismatch"
        done
    fi
    
    # Overall status
    if [ $missing -eq 0 ] && [ $mismatches -eq 0 ]; then
        log_success "🎉 All tests passed! Your WSL environment is properly configured."
        return 0
    elif [ $missing -gt 0 ]; then
        log_error "❌ Some software is missing. Consider running the installation script."
        return 1
    else
        log_warn "⚠️  Some version mismatches detected, but all software is installed."
        return 0
    fi
}

# Main function
main() {
    log_info "Starting WSL Installation Test Script"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Ensure yq is available
    ensure_yq
    
    # Validate configuration file
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Run tests
    test_apt_packages
    test_custom_software
    test_python_packages
    test_powershell_modules
    test_configurations
    
    # Generate report if requested
    generate_detailed_report
    
    # Show summary
    show_summary
    
    log_info "Test script completed!"
}

# Run main function with all arguments
main "$@"
