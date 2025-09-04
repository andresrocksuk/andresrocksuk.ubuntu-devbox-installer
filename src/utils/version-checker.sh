#!/bin/bash

# version-checker.sh - Version checking utilities for WSL installation

# Source logger
# Handle being sourced from different directories
if [ -n "${BASH_SOURCE[0]}" ]; then
    VERSION_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
    if [ "$VERSION_SCRIPT_DIR" = "${BASH_SOURCE[0]}" ]; then
        VERSION_SCRIPT_DIR="."
    fi
    VERSION_SCRIPT_DIR="$(cd "$VERSION_SCRIPT_DIR" && pwd)"
else
    VERSION_SCRIPT_DIR="${0%/*}"
    if [ "$VERSION_SCRIPT_DIR" = "$0" ]; then
        VERSION_SCRIPT_DIR="."
    fi
    VERSION_SCRIPT_DIR="$(cd "$VERSION_SCRIPT_DIR" && pwd)"
fi
source "$VERSION_SCRIPT_DIR/logger.sh"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get version of a command
get_command_version() {
    local cmd="$1"
    local version_flag="${2:---version}"
    
    # Add homebrew to PATH temporarily if it's not available
    local original_path="$PATH"
    if ! command -v brew >/dev/null 2>&1 && [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
    fi
    
    if ! command_exists "$cmd"; then
        # Restore original PATH
        export PATH="$original_path"
        echo "NOT_INSTALLED"
        return 1
    fi
    
    local version_output
    case "$cmd" in
        "node")
            version_output=$($cmd --version 2>/dev/null | sed 's/^v//')
            ;;
        "python3")
            version_output=$($cmd --version 2>/dev/null | awk '{print $2}')
            ;;
        "pip" | "pip3")
            version_output=$($cmd --version 2>/dev/null | awk '{print $2}')
            ;;
        "go")
            version_output=$($cmd version 2>/dev/null | awk '{print $3}' | sed 's/go//')
            ;;
        "dotnet")
            version_output=$($cmd --version 2>/dev/null)
            ;;
        "terraform")
            version_output=$($cmd version 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/^v//')
            ;;
        "kubectl")
            version_output=$($cmd version --client 2>/dev/null | grep "Client Version:" | awk '{print $3}' | sed 's/^v//')
            ;;
        "helm")
            version_output=$($cmd version --short 2>/dev/null | sed 's/^v//')
            ;;
        "az")
            version_output=$($cmd --version 2>/dev/null | grep "azure-cli" | awk '{print $2}')
            ;;
        "pwsh")
            version_output=$($cmd --version 2>/dev/null | awk '{print $2}')
            ;;
        "unzip")
            version_output=$($cmd -v 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "zip")
            version_output=$($cmd -v 2>/dev/null | grep "This is Zip" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "cue")
            version_output=$($cmd version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "yq")
            version_output=$($cmd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "fastfetch")
            version_output=$($cmd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "ytt")
            version_output=$($cmd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "tofu")
            version_output=$($cmd version 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/^v//')
            ;;
        "brew")
            # For homebrew, check if it's running as the correct user for proper version detection
            if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ] && command -v sudo >/dev/null 2>&1; then
                # Use the linuxbrew user to get accurate version info
                version_output=$(sudo -u linuxbrew /home/linuxbrew/.linuxbrew/bin/brew --version 2>/dev/null | sed 's/>=//g' | sed 's/-dirty//g' | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            else
                # Fallback to direct execution
                version_output=$($cmd --version 2>/dev/null | sed 's/>=//g' | sed 's/-dirty//g' | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            fi
            ;;
        "zoxide")
            version_output=$($cmd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "nix")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "bat")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "fzf")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "nano")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "k9s")
            version_output=$($cmd version 2>/dev/null | grep Version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "nvim")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "jq")
            version_output=$($cmd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "gcc")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "tree")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "htop")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "pipx")
            version_output=$($cmd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "pre-commit")
            version_output=$($cmd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "zsh")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "git")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "curl")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        "wget")
            version_output=$($cmd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
        *)
            version_output=$($cmd $version_flag 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -n1)
            ;;
    esac
    
    # Restore original PATH
    export PATH="$original_path"
    
    if [ -n "$version_output" ]; then
        echo "$version_output"
        return 0
    else
        echo "UNKNOWN"
        return 1
    fi
}

# Function to compare versions (returns 0 if version1 >= version2)
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Handle special cases
    if [ "$version1" = "NOT_INSTALLED" ] || [ "$version1" = "UNKNOWN" ]; then
        return 1
    fi
    
    if [ "$version2" = "latest" ]; then
        return 0  # Any installed version satisfies "latest"
    fi
    
    # Compare versions using sort -V
    if printf '%s\n%s\n' "$version2" "$version1" | sort -V -C; then
        return 0
    else
        return 1
    fi
}

# Function to check if software is installed with correct version
check_software_version() {
    local software="$1"
    local required_version="$2"
    local version_command="${3:-$software}"
    local version_flag="${4:---version}"
    
    log_debug "Checking version for $software (required: $required_version)"
    
    local current_version
    current_version=$(get_command_version "$version_command" "$version_flag")
    local check_result=$?
    
    if [ $check_result -eq 0 ] && [ "$current_version" != "NOT_INSTALLED" ] && [ "$current_version" != "UNKNOWN" ]; then
        if version_compare "$current_version" "$required_version"; then
            log_debug "$software is installed with version $current_version (satisfies $required_version)"
            return 0
        else
            log_debug "$software version $current_version does not satisfy $required_version"
            return 1
        fi
    else
        log_debug "$software is not installed or version unknown"
        return 1
    fi
}

# Function to get latest version from GitHub releases
get_github_latest_version() {
    local repo="$1"
    local version
    
    log_debug "Fetching latest version for GitHub repo: $repo"
    
    # Try using GitHub API
    if command_exists "curl"; then
        version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
    elif command_exists "wget"; then
        version=$(wget -qO- "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
    fi
    
    if [ -n "$version" ] && [ "$version" != "null" ]; then
        echo "$version"
        return 0
    else
        log_warn "Could not fetch latest version for $repo"
        echo "latest"
        return 1
    fi
}

# Function to get latest version from package manager
get_apt_latest_version() {
    local package="$1"
    local version
    
    log_debug "Fetching latest apt version for: $package"
    
    # Update package list if not done recently
    if [ ! -f "/var/lib/apt/periodic/update-success-stamp" ] || [ $(find /var/lib/apt/periodic/update-success-stamp -mmin +60 2>/dev/null | wc -l) -eq 1 ]; then
        log_debug "Updating apt package list (version check)"
        if command_exists safe_apt_update; then
            if ! safe_apt_update; then
                log_warn "safe_apt_update failed during version fetch for $package"
            fi
        else
            # Fallback minimal update without suppression
            if ! sudo -E apt-get update; then
                log_warn "apt-get update failed during version fetch for $package"
            fi
        fi
    fi
    
    version=$(apt-cache policy "$package" 2>/dev/null | grep "Candidate:" | awk '{print $2}')
    
    if [ -n "$version" ] && [ "$version" != "(none)" ]; then
        echo "$version"
        return 0
    else
        log_warn "Could not fetch latest apt version for $package"
        echo "latest"
        return 1
    fi
}

# Function to check Python package version
check_python_package_version() {
    local package="$1"
    local required_version="$2"
    
    log_debug "Checking Python package version for $package (required: $required_version)"
    
    # For command-line applications, check if the command exists first
    if command_exists "$package"; then
        log_debug "Python package $package is available as command-line tool"
        return 0
    fi
    
    if ! command_exists "python3"; then
        log_debug "Python3 not installed"
        return 1
    fi
    
    # Try to import the package and get its version
    local current_version
    current_version=$(python3 -c "import $package; print($package.__version__)" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$current_version" ]; then
        if version_compare "$current_version" "$required_version"; then
            log_debug "Python package $package is installed with version $current_version (satisfies $required_version)"
            return 0
        else
            log_debug "Python package $package version $current_version does not satisfy $required_version"
            return 1
        fi
    else
        # Try alternative version checking for packages that don't follow standard patterns
        if python3 -c "import $package" 2>/dev/null; then
            log_debug "Python package $package is installed (version check unavailable)"
            return 0
        else
            log_debug "Python package $package is not installed"
            return 1
        fi
    fi
}

# Function to check PowerShell module version
check_powershell_module_version() {
    local module="$1"
    local required_version="$2"
    
    log_debug "Checking PowerShell module version for $module (required: $required_version)"
    
    if ! command_exists "pwsh"; then
        log_debug "PowerShell not installed"
        return 1
    fi
    
    local current_version
    current_version=$(pwsh -Command "try { (Get-Module -ListAvailable -Name '$module' | Select-Object -First 1).Version.ToString() } catch { 'NOT_INSTALLED' }" 2>/dev/null)
    
    if [ "$current_version" != "NOT_INSTALLED" ] && [ -n "$current_version" ]; then
        if version_compare "$current_version" "$required_version"; then
            log_debug "PowerShell module $module is installed with version $current_version (satisfies $required_version)"
            return 0
        else
            log_debug "PowerShell module $module version $current_version does not satisfy $required_version"
            return 1
        fi
    else
        log_debug "PowerShell module $module is not installed"
        return 1
    fi
}

# Function to generate version report
generate_version_report() {
    local config_file="$1"
    local report_file="${2:-$(dirname "$config_file")/version-report.txt}"
    
    # Ensure the directory exists for the report file
    local report_dir="$(dirname "$report_file")"
    mkdir -p "$report_dir"
    
    log_info "Generating version report..."
    
    {
        echo "WSL Installation Version Report"
        echo "Generated: $(date)"
        if [ -n "$WSL_INSTALL_RUN_ID" ]; then
            echo "Run ID: $WSL_INSTALL_RUN_ID"
        fi
        echo "=================================="
        echo ""
        
        # Check apt packages if yq is available
        if command_exists "yq" && [ -f "$config_file" ]; then
            echo "APT Packages:"
            echo "-------------"
            yq eval '.apt_packages[] | .name + ":" + (.command // .name) + ":" + .version' "$config_file" 2>/dev/null | while IFS=: read -r package command required; do
                if [ -n "$package" ]; then
                    current=$(get_command_version "$command")
                    echo "  $package: $current (required: $required)"
                fi
            done
            echo ""
        fi
        
        echo "System Information:"
        echo "-------------------"
        echo "  OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
        echo "  Kernel: $(uname -r)"
        echo "  Architecture: $(uname -m)"
        echo ""
        
    } > "$report_file"
    
    log_success "Version report generated: $report_file"
}
