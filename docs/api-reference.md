# API Reference

This document provides a comprehensive reference for the utility functions, scripts, and APIs available in the WSL Ubuntu DevBox Installer system.

## Utility Libraries

### Logger Utility (`src/utils/logger.sh`)

Provides consistent logging functionality across all installation scripts.

#### Functions

##### `log_info(message)`
Logs informational messages in blue color.

```bash
log_info "Installing Docker Engine..."
```

##### `log_success(message)`
Logs success messages in green color.

```bash
log_success "Docker installed successfully"
```

##### `log_error(message)`
Logs error messages in red color.

```bash
log_error "Failed to install Docker"
```

##### `log_warn(message)`
Logs warning messages in yellow color.

```bash
log_warn "Docker service not running"
```

##### `log_debug(message)`
Logs debug messages (only shown when DEBUG level is enabled).

```bash
log_debug "Executing command: $command"
```

##### `log_section(title)`
Logs section headers with decorative formatting.

```bash
log_section "Installing Custom Software"
```

##### `set_log_level(level)`
Sets the current logging level.

```bash
set_log_level "DEBUG"  # DEBUG, INFO, WARN, ERROR
```

#### Usage Example

```bash
#!/bin/bash
# Source the logger utility
source "$UTILS_DIR/logger.sh"

# Use logging functions
log_info "Starting installation process"
log_debug "Configuration file: $CONFIG_FILE"

if command -v tool >/dev/null 2>&1; then
    log_success "Tool is already installed"
else
    log_error "Tool installation failed"
fi
```

### Package Manager Utility (`src/utils/package-manager.sh`)

Provides package management abstractions and utilities.

#### Functions

##### `update_package_lists()`
Updates apt package lists with lock file handling.

```bash
update_package_lists
```

##### `install_apt_package(name, version, force)`
Installs an apt package with version handling.

```bash
install_apt_package "git" "latest" false
install_apt_package "python3" "3.11*" true
```

**Parameters:**
- `name`: Package name (required)
- `version`: Version specification or "latest" (required)
- `force`: Boolean, force reinstall if true (required)

**Returns:** 0 for success, 1 for failure

##### `cleanup_package_cache()`
Cleans apt package cache to free disk space.

```bash
cleanup_package_cache
```

##### `command_exists(command)`
Checks if a command is available in PATH.

```bash
if command_exists "docker"; then
    log_info "Docker is available"
fi
```

##### `get_installed_version(command, flag)`
Gets the version of an installed command.

```bash
version=$(get_installed_version "git" "--version")
log_info "Git version: $version"
```

### Version Checker Utility (`src/utils/version-checker.sh`)

Provides version comparison and validation functions.

#### Functions

##### `check_version_requirement(installed, required)`
Compares installed version against requirement.

```bash
if check_version_requirement "1.2.3" ">=1.2.0"; then
    log_success "Version requirement satisfied"
fi
```

**Parameters:**
- `installed`: Currently installed version string
- `required`: Version requirement (supports >=, <=, ==, >, <, patterns)

**Returns:** 0 if requirement met, 1 if not met

##### `extract_version_number(version_string)`
Extracts version number from command output.

```bash
version_output="git version 2.34.1"
version=$(extract_version_number "$version_output")
echo $version  # Output: 2.34.1
```

##### `compare_versions(version1, operator, version2)`
Compares two version numbers with operator.

```bash
if compare_versions "1.2.3" ">=" "1.2.0"; then
    echo "Version check passed"
fi
```

**Supported operators:** `>`, `>=`, `<`, `<=`, `==`, `!=`

## Installation Script APIs

### Main Installation Script (`src/install.sh`)

#### Command Line Interface

```bash
./install.sh [OPTIONS]

Options:
    -h, --help          Show help message
    -f, --force         Force reinstallation of all software
    -d, --dry-run       Show what would be installed without installing
    --run-apt-upgrade   Run apt-get upgrade after apt-get update
    -l, --log-level     Set log level (DEBUG, INFO, WARN, ERROR)
    -c, --config        Specify custom config file
    -s, --sections      Specify sections to run (comma-separated)
    -v, --version       Show script version
```

#### Environment Variables

##### `WSL_INSTALL_RUN_ID`
Unique identifier for the current installation run.

```bash
export WSL_INSTALL_RUN_ID="20250827_120000"
```

##### `WSL_INSTALL_TEMP_MODE`
Indicates if running in temporary directory mode.

```bash
export WSL_INSTALL_TEMP_MODE="true"
```

##### `LOG_DIR`
Directory for log file output.

```bash
export LOG_DIR="/path/to/logs"
```

### Test Installation Script (`src/tests/test-installation.sh`)

#### Command Line Interface

```bash
./test-installation.sh [OPTIONS]

Options:
    -h, --help          Show help message
    -r, --report        Generate detailed report file
    -s, --software      Test specific software (comma-separated)
    -l, --log-level     Set log level
    -v, --version       Show script version
```

#### Usage Examples

```bash
# Test all installations
./test-installation.sh

# Test specific software
./test-installation.sh --software "git,python3,docker"

# Generate detailed report
./test-installation.sh --report
```

## PowerShell Scripts API

### Main WSL Script (`install-wsl.ps1`)

#### Parameters

```powershell
[CmdletBinding()]
param(
    [switch]$AutoInstall,           # Auto-create WSL user
    [switch]$Force,                 # Skip prompts, use defaults
    [switch]$ResetWSL,              # Reset WSL distribution
    [switch]$RunDirect,             # Run without temp directory
    [string]$Distribution,          # WSL distribution name
    [string]$InstallPath,           # Path to installation scripts
    [string[]]$Config               # Configuration sections to run
)
```

#### Usage Examples

```powershell
# Basic installation
.\install-wsl.ps1 -AutoInstall

# Reset and reinstall
.\install-wsl.ps1 -ResetWSL -AutoInstall

# Selective installation
.\install-wsl.ps1 -AutoInstall -Config "prerequisites","apt_packages"

# Unattended installation
$env:WSL_DEFAULT_PASSWORD = "password"
.\install-wsl.ps1 -AutoInstall -Force
```

#### Environment Variables

##### `WSL_DEFAULT_USERNAME`
Default username for WSL user creation.

```powershell
$env:WSL_DEFAULT_USERNAME = "developer"
```

##### `WSL_DEFAULT_PASSWORD`
Default password for unattended installation.

```powershell
$env:WSL_DEFAULT_PASSWORD = "SecurePassword123!"
```

### Test WSL Script (`test-installation-wsl.ps1`)

#### Parameters

```powershell
[CmdletBinding()]
param(
    [string]$Distribution = "Ubuntu-24.04"
)
```

#### Usage

```powershell
# Test with default distribution
.\test-installation-wsl.ps1

# Test with specific distribution
.\test-installation-wsl.ps1 -Distribution "Ubuntu-22.04"
```

## Custom Installation Script Template

When creating new software installation scripts, follow this template:

```bash
#!/bin/bash

# Software installation script template
# Replace "example-tool" with your tool name

set -e

# Get script directory for utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/../utils"

# Source utilities if available
if [ -f "$UTILS_DIR/logger.sh" ]; then
    source "$UTILS_DIR/logger.sh"
else
    # Fallback logging functions
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
fi

install_example_tool() {
    log_info "Installing Example Tool..."
    
    # Check if already installed
    if command -v example-tool >/dev/null 2>&1; then
        local current_version=$(example-tool --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "Example Tool is already installed (version: $current_version)"
        return 0
    fi
    
    # Installation logic here
    log_info "Downloading Example Tool..."
    
    # Example: Download and install
    local temp_file="/tmp/example-tool"
    if command -v curl >/dev/null 2>&1; then
        curl -L "https://releases.example.com/tool" -o "$temp_file"
    elif command -v wget >/dev/null 2>&1; then
        wget "https://releases.example.com/tool" -O "$temp_file"
    else
        log_error "Neither curl nor wget available"
        return 1
    fi
    
    # Install the tool
    chmod +x "$temp_file"
    sudo mv "$temp_file" /usr/local/bin/example-tool
    
    # Verify installation
    if command -v example-tool >/dev/null 2>&1; then
        local installed_version=$(example-tool --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "Example Tool installed successfully (version: $installed_version)"
        
        # Test the installation
        log_info "Testing Example Tool installation..."
        example-tool --help >/dev/null && log_success "Example Tool test successful"
        
        return 0
    else
        log_error "Example Tool installation verification failed"
        return 1
    fi
}

# Run installation
install_example_tool
```

## YAML Configuration API

### Accessing Configuration Values

Using `yq` to read configuration values:

```bash
# Read metadata
name=$(yq eval '.metadata.name' "$CONFIG_FILE")
version=$(yq eval '.metadata.version' "$CONFIG_FILE")

# Read settings with defaults
continue_on_error=$(yq eval '.settings.continue_on_error // true' "$CONFIG_FILE")
log_level=$(yq eval '.settings.log_level // "INFO"' "$CONFIG_FILE")

# Read array lengths
apt_count=$(yq eval '.apt_packages | length' "$CONFIG_FILE")

# Iterate over arrays
for i in $(seq 0 $((apt_count - 1))); do
    name=$(yq eval ".apt_packages[$i].name" "$CONFIG_FILE")
    version=$(yq eval ".apt_packages[$i].version // \"latest\"" "$CONFIG_FILE")
    description=$(yq eval ".apt_packages[$i].description // \"\"" "$CONFIG_FILE")
done
```

### Configuration Validation

```bash
# Validate YAML syntax
if ! yq eval '.' "$CONFIG_FILE" >/dev/null 2>&1; then
    log_error "Invalid YAML syntax in configuration file"
    exit 1
fi

# Check required fields
if [ "$(yq eval '.metadata.name' "$CONFIG_FILE")" = "null" ]; then
    log_error "Missing required field: metadata.name"
    exit 1
fi
```

## Error Handling Patterns

### Standard Error Handling

```bash
# Function with error handling
install_software() {
    local software_name="$1"
    
    log_info "Installing $software_name..."
    
    # Attempt installation
    if ! some_install_command; then
        log_error "Failed to install $software_name"
        return 1
    fi
    
    # Verify installation
    if ! command -v "$software_name" >/dev/null 2>&1; then
        log_error "$software_name installation verification failed"
        return 1
    fi
    
    log_success "$software_name installed successfully"
    return 0
}
```

### Network Error Handling

```bash
# Download with retry logic
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Download attempt $attempt/$max_attempts..."
        
        if curl -L "$url" -o "$output"; then
            log_success "Download successful"
            return 0
        fi
        
        log_warn "Download attempt $attempt failed"
        attempt=$((attempt + 1))
        
        if [ $attempt -le $max_attempts ]; then
            sleep 5
        fi
    done
    
    log_error "Download failed after $max_attempts attempts"
    return 1
}
```

### Dependency Checking

```bash
# Check dependencies before installation
check_dependencies() {
    local dependencies=("$@")
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}
```

## Testing API

### Writing Custom Tests

```bash
# Test function template
test_software_installation() {
    local software_name="$1"
    local expected_command="$2"
    
    echo "Testing $software_name installation..."
    
    # Check command exists
    if ! command -v "$expected_command" >/dev/null 2>&1; then
        echo "❌ $software_name: Command '$expected_command' not found"
        return 1
    fi
    
    # Check version
    local version_output
    if version_output=$("$expected_command" --version 2>/dev/null); then
        echo "✅ $software_name: $version_output"
        return 0
    else
        echo "⚠️  $software_name: Available but version check failed"
        return 1
    fi
}
```

### Integration with Test Framework

```bash
# Add test to main test suite
# In src/tests/test-installation.sh

test_my_software() {
    test_software_installation "My Software" "my-command"
}

# Register test in main test loop
# Add to the software testing section
```

This API reference provides comprehensive information for extending and customizing the WSL Ubuntu DevBox Installer system.
