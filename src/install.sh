#!/bin/bash

# install.sh - Main WSL installation script
# This script reads the install.yaml configuration and installs all specified software

set -e  # Exit on any error

# Script directory and paths
SCRIPT_DIR="${0%/*}"
if [ "$SCRIPT_DIR" = "$0" ]; then
    SCRIPT_DIR="."
fi
SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"

# Store the original source directory for resolving relative paths
# This is important for temp mode where SCRIPT_DIR points to temp directory
if [ -n "$WSL_INSTALL_TEMP_MODE" ]; then
    # In temp mode, we need to know the original source directory
    # The original source directory should be passed as an environment variable
    if [ -n "$WSL_INSTALL_SOURCE_DIR" ]; then
        ORIGINAL_SOURCE_DIR="$WSL_INSTALL_SOURCE_DIR"
    else
        # Fallback: assume we're one level deep from the original source
        ORIGINAL_SOURCE_DIR="$(dirname "$SCRIPT_DIR")/src"
    fi
else
    # In direct mode, SCRIPT_DIR is the source directory
    ORIGINAL_SOURCE_DIR="$SCRIPT_DIR"
fi

CONFIG_FILE="$SCRIPT_DIR/install.yaml"
UTILS_DIR="$SCRIPT_DIR/utils"

# Set log directory before sourcing logger
export LOG_DIR="$SCRIPT_DIR/logs"

# Source utilities first (before any logging calls)
source "$UTILS_DIR/logger.sh"

# Generate unique run ID for this execution (only if not already set)
if [ -z "$WSL_INSTALL_RUN_ID" ]; then
    export WSL_INSTALL_RUN_ID="$(date +%Y%m%d_%H%M%S)"
    log_info "Generated new run ID: $WSL_INSTALL_RUN_ID"
else
    log_info "Using provided run ID: $WSL_INSTALL_RUN_ID"
fi
source "$UTILS_DIR/version-checker.sh"
source "$UTILS_DIR/package-manager.sh"
source "$UTILS_DIR/installation-framework.sh"

# Global variables
INSTALLATION_SUMMARY=()
FAILED_INSTALLATIONS=()
FORCE_INSTALL=false
DRY_RUN=false
RUN_APT_UPGRADE=false
SELECTED_SECTIONS=()
CONFIG_ARG=""

# Function to display help
show_help() {
    cat << EOF
WSL Installation Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -f, --force         Force reinstallation of all software
    -d, --dry-run       Show what would be installed without actually installing
    --run-apt-upgrade   Run apt-get upgrade after apt-get update (default: false)
    -l, --log-level     Set log level (DEBUG, INFO, WARN, ERROR)
    -c, --config        Specify custom config file (default: install.yaml)
    -s, --sections      Specify which sections to run (comma-separated): prerequisites,apt_packages,shell_setup,custom_software,python_packages,powershell_modules,nix_packages,configurations
    -v, --version       Show script version

Examples:
    $0                  # Install everything from install.yaml
    $0 --force          # Force reinstall everything
    $0 --dry-run        # Show installation plan
    $0 --log-level DEBUG  # Enable debug logging
    $0 --sections prerequisites,apt_packages  # Only run specific sections

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
            -f|--force)
                FORCE_INSTALL=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --run-apt-upgrade)
                RUN_APT_UPGRADE=true
                shift
                ;;
            -l|--log-level)
                set_log_level "$2"
                shift 2
                ;;
            -c|--config)
                # Store the config argument for later resolution
                CONFIG_ARG="$2"
                shift 2
                ;;
            -s|--sections)
                IFS=',' read -ra SELECTED_SECTIONS <<< "$2"
                shift 2
                ;;
            -v|--version)
                echo "WSL Installation Script v1.0.0"
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

# Function to check if a section should be run
should_run_section() {
    local section_name="$1"
    
    # If no sections are specified, run all sections
    if [ ${#SELECTED_SECTIONS[@]} -eq 0 ]; then
        return 0
    fi
    
    # Check if the section is in the selected sections
    for selected in "${SELECTED_SECTIONS[@]}"; do
        if [ "$selected" = "$section_name" ]; then
            return 0
        fi
    done
    
    return 1
}

# Function to validate selected sections
validate_sections() {
    if [ ${#SELECTED_SECTIONS[@]} -eq 0 ]; then
        return 0
    fi
    
    local valid_sections=("prerequisites" "apt_packages" "shell_setup" "custom_software" "python_packages" "powershell_modules" "nix_packages" "configurations")
    
    for selected in "${SELECTED_SECTIONS[@]}"; do
        local valid=false
        for valid_section in "${valid_sections[@]}"; do
            if [ "$selected" = "$valid_section" ]; then
                valid=true
                break
            fi
        done
        
        if [ "$valid" = false ]; then
            log_error "Invalid section specified: $selected"
            log_error "Valid sections are: ${valid_sections[*]}"
            exit 1
        fi
    done
}

# Function to resolve configuration profile
resolve_config_profile() {
    local config_arg="$1"
    
    # If no config argument provided, use default profile
    if [ -z "$config_arg" ]; then
        CONFIG_FILE="$SCRIPT_DIR/config-profiles/full-install.yaml"
        log_info "Using default configuration profile: $CONFIG_FILE"
        return 0
    fi
    
    # If it's a URL, use as-is
    if [[ "$config_arg" =~ ^https?:// ]]; then
        CONFIG_FILE="$config_arg"
        log_info "Using remote configuration: $CONFIG_FILE"
        return 0
    fi
    
    # If it's an absolute path, use as-is
    if [[ "$config_arg" =~ ^/ ]]; then
        CONFIG_FILE="$config_arg"
        log_info "Using absolute path configuration: $CONFIG_FILE"
        return 0
    fi
    
    # Check if it's a profile name without path
    if [[ "$config_arg" =~ ^[a-zA-Z0-9._-]+\.ya?ml$ ]]; then
        # Try to find it in config-profiles directory
        local profile_path="$SCRIPT_DIR/config-profiles/$config_arg"
        if [ -f "$profile_path" ]; then
            CONFIG_FILE="$profile_path"
            log_info "Using profile from config-profiles: $CONFIG_FILE"
            return 0
        fi
    fi
    
    # Handle relative paths - resolve relative to the original source directory's parent
    CONFIG_FILE="$(dirname "$ORIGINAL_SOURCE_DIR")/$config_arg"
    log_info "Using relative path configuration: $CONFIG_FILE"
}

# Function to generate install.yaml from resolved profile
generate_install_yaml() {
    local source_config="$CONFIG_FILE"
    local target_config="$SCRIPT_DIR/install.yaml"
    
    # If source is a URL, download it first
    if [[ "$source_config" =~ ^https?:// ]]; then
        log_info "Downloading remote configuration from: $source_config"
        
        # Create temp file for the remote config
        local temp_config="/tmp/wsl-remote-config-$WSL_INSTALL_RUN_ID.yaml"
        
        # Try to download with curl first, then wget
        if command_exists "curl"; then
            if curl -s -L "$source_config" -o "$temp_config"; then
                log_success "Successfully downloaded remote configuration with curl"
                source_config="$temp_config"
            else
                log_error "Failed to download remote configuration with curl"
                return 1
            fi
        elif command_exists "wget"; then
            if wget -q "$source_config" -O "$temp_config"; then
                log_success "Successfully downloaded remote configuration with wget"
                source_config="$temp_config"
            else
                log_error "Failed to download remote configuration with wget"
                return 1
            fi
        else
            log_error "Neither curl nor wget available to download remote configuration"
            return 1
        fi
    fi
    
    # Validate source configuration exists
    if [ ! -f "$source_config" ]; then
        log_error "Configuration file not found: $source_config"
        return 1
    fi
    
    # Validate YAML syntax
    if command_exists "yq"; then
        if ! yq eval '.' "$source_config" >/dev/null 2>&1; then
            log_error "Invalid YAML syntax in configuration: $source_config"
            return 1
        fi
    fi
    
    # Copy the configuration to install.yaml
    log_info "Generating install.yaml from profile: $source_config"
    cp "$source_config" "$target_config"
    
    if [ $? -eq 0 ]; then
        log_success "Successfully generated install.yaml"
        # Update CONFIG_FILE to point to the generated file
        CONFIG_FILE="$target_config"
        return 0
    else
        log_error "Failed to generate install.yaml from profile"
        return 1
    fi
}

# Function to download remote configuration file if needed
download_remote_config() {
    # This function is now deprecated - functionality moved to generate_install_yaml
    # Keeping for backward compatibility but will redirect to new function
    log_info "Redirecting to new configuration profile system..."
    generate_install_yaml
    return $?
}

# Function to read and display metadata from config
read_metadata() {
    log_section "Configuration Metadata"
    
    local name=$(yq eval '.metadata.name // "WSL Development Environment"' "$CONFIG_FILE")
    local description=$(yq eval '.metadata.description // ""' "$CONFIG_FILE")
    local version=$(yq eval '.metadata.version // "1.0.0"' "$CONFIG_FILE")
    local author=$(yq eval '.metadata.author // ""' "$CONFIG_FILE")
    local support_url=$(yq eval '.metadata.support_url // ""' "$CONFIG_FILE")
    
    log_info "Name: $name"
    if [ -n "$description" ]; then
        log_info "Description: $description"
    fi
    log_info "Version: $version"
    if [ -n "$author" ]; then
        log_info "Author: $author"
    fi
    if [ -n "$support_url" ]; then
        log_info "Support URL: $support_url"
        export WSL_INSTALL_SUPPORT_URL="$support_url"
    fi
}

# Function to check if yq is available for YAML parsing
ensure_yq() {
    if ! command_exists "yq"; then
        log_info "Installing yq for YAML parsing..."
        
        # Download and install yq
        local yq_version="v4.44.3"
        local yq_binary="yq_linux_amd64"
        local yq_url="https://github.com/mikefarah/yq/releases/download/${yq_version}/${yq_binary}"
        
        if command_exists "curl"; then
            curl -L "$yq_url" -o "/tmp/yq"
        elif command_exists "wget"; then
            wget "$yq_url" -O "/tmp/yq"
        else
            log_error "Neither curl nor wget available for downloading yq"
            exit 1
        fi
        
        chmod +x "/tmp/yq"
        sudo mv "/tmp/yq" "/usr/local/bin/yq"
        
        if command_exists "yq"; then
            log_success "yq installed successfully"
        else
            log_error "Failed to install yq"
            exit 1
        fi
    fi
}

# Function to validate configuration file
validate_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    log_info "Validating configuration file: $CONFIG_FILE"
    
    # Check if file is valid YAML
    if ! yq eval '.' "$CONFIG_FILE" >/dev/null 2>&1; then
        log_error "Invalid YAML syntax in configuration file"
        exit 1
    fi
    
    log_success "Configuration file is valid"
}

# Function to read settings from config
read_settings() {
    local continue_on_error=$(yq eval '.settings.continue_on_error // true' "$CONFIG_FILE")
    local log_level=$(yq eval '.settings.log_level // "INFO"' "$CONFIG_FILE")
    
    if [ "$continue_on_error" = "false" ]; then
        set -e
    else
        set +e
    fi
    
    set_log_level "$log_level"
}

# Function to install prerequisites
install_prerequisites() {
    log_section "Installing Prerequisites"
    
    local prerequisites
    prerequisites=$(yq eval '.prerequisites[]' "$CONFIG_FILE" 2>/dev/null)
    
    if [ -z "$prerequisites" ]; then
        log_info "No prerequisites defined"
        return 0
    fi
    
    update_package_lists
    
    echo "$prerequisites" | while read -r package; do
        if [ -n "$package" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would install prerequisite: $package"
            else
                install_apt_package "$package" "latest" "$FORCE_INSTALL"
            fi
        fi
    done
}

# Function to install apt packages
install_apt_packages() {
    log_section "Installing APT Packages"

    # Always update package lists before installing any apt packages
    update_package_lists

    local apt_packages
    apt_packages=$(yq eval '.apt_packages | length' "$CONFIG_FILE" 2>/dev/null)

    if [ "$apt_packages" = "0" ] || [ "$apt_packages" = "null" ]; then
        log_info "No apt packages defined"
        return 0
    fi

    log_info "Found $apt_packages APT packages to install"

    for i in $(seq 0 $((apt_packages - 1))); do
        local name=$(yq eval ".apt_packages[$i].name" "$CONFIG_FILE")
        local version=$(yq eval ".apt_packages[$i].version // \"latest\"" "$CONFIG_FILE")
        local description=$(yq eval ".apt_packages[$i].description // \"\"" "$CONFIG_FILE")

        if [ -n "$name" ] && [ "$name" != "null" ]; then
            log_info "Processing package $((i + 1))/$apt_packages: $name"
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would install: $name ($version) - $description"
            else
                if install_apt_package "$name" "$version" "$FORCE_INSTALL"; then
                    INSTALLATION_SUMMARY+=("✅ $name ($version)")
                else
                    FAILED_INSTALLATIONS+=("❌ $name ($version)")
                fi
            fi
        fi
    done
}

# Function to install custom software
install_custom_software() {
    log_section "Installing Custom Software"
    
    local custom_software
    custom_software=$(yq eval '.custom_software | length' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$custom_software" = "0" ] || [ "$custom_software" = "null" ]; then
        log_info "No custom software defined"
        return 0
    fi
    
    log_info "Found $custom_software custom software packages to install"
    
    for i in $(seq 0 $((custom_software - 1))); do
        local name=$(yq eval ".custom_software[$i].name" "$CONFIG_FILE")
        local script=$(yq eval ".custom_software[$i].script" "$CONFIG_FILE")
        local description=$(yq eval ".custom_software[$i].description // \"\"" "$CONFIG_FILE")
        local depends_on=$(yq eval ".custom_software[$i].depends_on[]?" "$CONFIG_FILE" 2>/dev/null)
        
        if [ -n "$name" ] && [ "$name" != "null" ]; then
            log_info "Processing software $((i + 1))/$custom_software: $name"
            
            # Check dependencies
            if [ -n "$depends_on" ]; then
                log_debug "Checking dependencies for $name: $depends_on"
                echo "$depends_on" | while read -r dep; do
                    if [ -n "$dep" ] && ! command_exists "$dep"; then
                        log_warn "Dependency $dep not found for $name"
                    fi
                done
            fi
            
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would install: $name - $description"
            else
                local script_path="$SCRIPT_DIR/$script"
                if run_custom_installation_script "$name" "$script_path" "$FORCE_INSTALL"; then
                    INSTALLATION_SUMMARY+=("✅ $name (custom)")
                else
                    FAILED_INSTALLATIONS+=("❌ $name (custom)")
                fi
            fi
        fi
    done
}

# Function to install Python packages
install_python_packages() {
    log_section "Installing Python Packages"
    
    # Check if Python and pip are available
    if ! command_exists "python3"; then
        log_error "Python3 not available. Skipping Python packages."
        return 1
    fi
    
    if ! command_exists "pip3" && ! python3 -m pip --version >/dev/null 2>&1; then
        log_error "pip not available. Skipping Python packages."
        return 1
    fi

    local python_packages
    python_packages=$(yq eval '.python_packages | length' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$python_packages" = "0" ] || [ "$python_packages" = "null" ]; then
        log_info "No Python packages defined"
        return 0
    fi

    # Track if any packages were installed
    local packages_installed=false

    for i in $(seq 0 $((python_packages - 1))); do
        local name=$(yq eval ".python_packages[$i].name" "$CONFIG_FILE")
        local version=$(yq eval ".python_packages[$i].version // \"latest\"" "$CONFIG_FILE")
        local description=$(yq eval ".python_packages[$i].description // \"\"" "$CONFIG_FILE")
        
        if [ -n "$name" ] && [ "$name" != "null" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would install Python package: $name ($version) - $description"
            else
                if install_python_package "$name" "$version" "$FORCE_INSTALL"; then
                    INSTALLATION_SUMMARY+=("✅ $name ($version) [Python]")
                    packages_installed=true
                else
                    FAILED_INSTALLATIONS+=("❌ $name ($version) [Python]")
                fi
            fi
        fi
    done
}

# Function to install PowerShell modules
install_powershell_modules() {
    log_section "Installing PowerShell Modules"
    
    # Check if PowerShell is available
    if ! command_exists "pwsh"; then
        log_error "PowerShell not available. Skipping PowerShell modules."
        return 1
    fi
    
    local powershell_modules
    powershell_modules=$(yq eval '.powershell_modules | length' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$powershell_modules" = "0" ] || [ "$powershell_modules" = "null" ]; then
        log_info "No PowerShell modules defined"
        return 0
    fi
    
    for i in $(seq 0 $((powershell_modules - 1))); do
        local name=$(yq eval ".powershell_modules[$i].name" "$CONFIG_FILE")
        local version=$(yq eval ".powershell_modules[$i].version // \"latest\"" "$CONFIG_FILE")
        local description=$(yq eval ".powershell_modules[$i].description // \"\"" "$CONFIG_FILE")
        
        if [ -n "$name" ] && [ "$name" != "null" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would install PowerShell module: $name ($version) - $description"
            else
                if install_powershell_module "$name" "$version" "$FORCE_INSTALL"; then
                    INSTALLATION_SUMMARY+=("✅ $name ($version) [PowerShell]")
                else
                    FAILED_INSTALLATIONS+=("❌ $name ($version) [PowerShell]")
                fi
            fi
        fi
    done
}

# Function to install Nix packages
install_nix_packages() {
    log_section "Installing Nix Packages"
    
    # Check if the section should be run
    if ! should_run_section "nix_packages"; then
        log_info "Skipping nix_packages section (not selected)"
        return 0
    fi
    
    local nix_packages
    nix_packages=$(yq eval '.nix_packages | length' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$nix_packages" = "0" ] || [ "$nix_packages" = "null" ]; then
        log_info "No Nix packages defined"
        return 0
    fi
    
    log_info "Found $nix_packages Nix package configuration(s)"
    
    # Check if Nix is available, and install it if needed
    if ! command_exists "nix"; then
        log_warn "Nix is not available. Installing Nix first..."
        
        # Try to install Nix using the custom software script
        local nix_script="$SCRIPT_DIR/custom-software/nix/install.sh"
        
        if [ -f "$nix_script" ]; then
            log_info "Running Nix installation script..."
            if bash "$nix_script"; then
                log_success "Nix installed successfully"
                
                # Source Nix environment
                if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
                    source "$HOME/.nix-profile/etc/profile.d/nix.sh"
                elif [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
                    source "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
                fi
                
                # Verify Nix is now available
                if ! command_exists "nix"; then
                    log_error "Nix installation completed but command is still not available"
                    log_info "You may need to restart your shell or source the Nix profile manually"
                    FAILED_INSTALLATIONS+=("❌ Nix packages [Nix not available after installation]")
                    return 1
                fi
            else
                log_error "Failed to install Nix"
                FAILED_INSTALLATIONS+=("❌ Nix packages [Nix installation failed]")
                return 1
            fi
        else
            log_error "Nix installation script not found: $nix_script"
            log_info "Please ensure Nix is installed before running Nix packages, or include 'custom_software' section"
            FAILED_INSTALLATIONS+=("❌ Nix packages [Nix installation script not found]")
            return 1
        fi
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would process Nix packages configuration"
        
        # Show what would be installed
        for i in $(seq 0 $((nix_packages - 1))); do
            local has_flake=$(yq eval ".nix_packages[$i] | has(\"flake\")" "$CONFIG_FILE" 2>/dev/null)
            local has_packages=$(yq eval ".nix_packages[$i] | has(\"packages\")" "$CONFIG_FILE" 2>/dev/null)
            
            if [ "$has_flake" = "true" ]; then
                local enabled=$(yq eval ".nix_packages[$i].flake.enabled // false" "$CONFIG_FILE")
                if [ "$enabled" = "true" ]; then
                    local description=$(yq eval ".nix_packages[$i].flake.description // \"Nix flake\"" "$CONFIG_FILE")
                    local flake_type=$(yq eval ".nix_packages[$i].flake.type" "$CONFIG_FILE")
                    local source=""
                    
                    if [ "$flake_type" = "local" ]; then
                        source=$(yq eval ".nix_packages[$i].flake.path" "$CONFIG_FILE")
                    elif [ "$flake_type" = "remote" ]; then
                        source=$(yq eval ".nix_packages[$i].flake.url" "$CONFIG_FILE")
                    fi
                    
                    log_info "[DRY RUN] Would install flake: $description ($flake_type: $source)"
                fi
            fi
            
            if [ "$has_packages" = "true" ]; then
                local enabled=$(yq eval ".nix_packages[$i].packages.enabled // false" "$CONFIG_FILE")
                if [ "$enabled" = "true" ]; then
                    local packages_count=$(yq eval ".nix_packages[$i].packages.list | length" "$CONFIG_FILE" 2>/dev/null)
                    log_info "[DRY RUN] Would install $packages_count individual Nix packages"
                    
                    for j in $(seq 0 $((packages_count - 1))); do
                        local name=$(yq eval ".nix_packages[$i].packages.list[$j].name" "$CONFIG_FILE")
                        local package=$(yq eval ".nix_packages[$i].packages.list[$j].package" "$CONFIG_FILE")
                        local description=$(yq eval ".nix_packages[$i].packages.list[$j].description // \"\"" "$CONFIG_FILE")
                        log_info "[DRY RUN]   - $name ($package) - $description"
                    done
                fi
            fi
        done
        
        return 0
    fi
    
    # Run the nix-packages installation script
    local nix_packages_script="$SCRIPT_DIR/custom-software/nix-packages/install.sh"
    
    if [ ! -f "$nix_packages_script" ]; then
        log_error "Nix packages installation script not found: $nix_packages_script"
        FAILED_INSTALLATIONS+=("❌ Nix packages [Script not found]")
        return 1
    fi
    
    log_info "Running Nix packages installation script..."
    
    if bash "$nix_packages_script"; then
        INSTALLATION_SUMMARY+=("✅ Nix packages [Configured]")
        log_success "Nix packages configured successfully"
        return 0
    else
        FAILED_INSTALLATIONS+=("❌ Nix packages [Installation failed]")
        log_error "Nix packages installation failed"
        return 1
    fi
}

run_shell_setup() {
    log_section "Running Shell Setup"
    
    local shell_setup
    shell_setup=$(yq eval '.shell_setup | length' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$shell_setup" = "0" ] || [ "$shell_setup" = "null" ]; then
        log_info "No shell setup defined"
        return 0
    fi
    
    for i in $(seq 0 $((shell_setup - 1))); do
        local name=$(yq eval ".shell_setup[$i].name" "$CONFIG_FILE")
        local description=$(yq eval ".shell_setup[$i].description // \"\"" "$CONFIG_FILE")
        local enabled=$(yq eval ".shell_setup[$i].enabled // true" "$CONFIG_FILE")
        local script=$(yq eval ".shell_setup[$i].script" "$CONFIG_FILE")
        
        if [ -n "$name" ] && [ "$name" != "null" ] && [ "$enabled" = "true" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would run shell setup: $name - $description"
            else
                log_info "Running shell setup: $name"
                
                # Check if this is a script path or inline script
                if [[ "$script" == *"/"* ]] && [[ ! "$script" == *$'
'* ]]; then
                    # This is a script file path
                    local script_path="$SCRIPT_DIR/$script"
                    if [ -f "$script_path" ]; then
                        if bash "$script_path"; then
                            log_success "Shell setup completed: $name"
                            INSTALLATION_SUMMARY+=("✅ $name [Shell]")
                        else
                            log_error "Shell setup failed: $name"
                            FAILED_INSTALLATIONS+=("❌ $name [Shell]")
                        fi
                    else
                        log_error "Shell setup script not found: $script_path"
                        FAILED_INSTALLATIONS+=("❌ $name [Shell] - Script not found")
                    fi
                else
                    # This is inline script content
                    if eval "$script"; then
                        log_success "Shell setup completed: $name"
                        INSTALLATION_SUMMARY+=("✅ $name [Shell]")
                    else
                        log_error "Shell setup failed: $name"
                        FAILED_INSTALLATIONS+=("❌ $name [Shell]")
                    fi
                fi
            fi
        else
            log_info "Skipping disabled shell setup: $name"
        fi
    done
}

# Function to run configurations
run_configurations() {
    log_section "Running Configurations"
    
    local configurations
    configurations=$(yq eval '.configurations | length' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$configurations" = "0" ] || [ "$configurations" = "null" ]; then
        log_info "No configurations defined"
        return 0
    fi
    
    for i in $(seq 0 $((configurations - 1))); do
        local name=$(yq eval ".configurations[$i].name" "$CONFIG_FILE")
        local description=$(yq eval ".configurations[$i].description // \"\"" "$CONFIG_FILE")
        local enabled=$(yq eval ".configurations[$i].enabled // true" "$CONFIG_FILE")
        local script=$(yq eval ".configurations[$i].script" "$CONFIG_FILE")
        
        if [ -n "$name" ] && [ "$name" != "null" ] && [ "$enabled" = "true" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "[DRY RUN] Would run configuration: $name - $description"
            else
                log_info "Running configuration: $name"
                
                # Check if this is a script path or inline script
                if [[ "$script" == *"/"* ]] && [[ ! "$script" == *$'\n'* ]]; then
                    # This is a script file path
                    local script_path="$SCRIPT_DIR/$script"
                    if [ -f "$script_path" ]; then
                        if bash "$script_path"; then
                            log_success "Configuration completed: $name"
                            INSTALLATION_SUMMARY+=("✅ $name [Config]")
                        else
                            log_error "Configuration failed: $name"
                            FAILED_INSTALLATIONS+=("❌ $name [Config]")
                        fi
                    else
                        log_error "Configuration script not found: $script_path"
                        FAILED_INSTALLATIONS+=("❌ $name [Config]")
                    fi
                else
                    # This is inline script
                    if eval "$script"; then
                        log_success "Configuration completed: $name"
                        INSTALLATION_SUMMARY+=("✅ $name [Config]")
                    else
                        log_error "Configuration failed: $name"
                        FAILED_INSTALLATIONS+=("❌ $name [Config]")
                    fi
                fi
            fi
        fi
    done
}

# Function to cleanup
cleanup() {
    local cleanup_setting=$(yq eval '.settings.cleanup_after_install // true' "$CONFIG_FILE")
    
    if [ "$cleanup_setting" = "true" ] && [ "$DRY_RUN" != "true" ]; then
        log_section "Cleanup"
        cleanup_package_cache
    fi
}

# Function to show installation summary
show_summary() {
    log_section "Installation Summary"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "Dry run completed. No actual installations were performed."
        return 0
    fi
    
    local total_attempted=$((${#INSTALLATION_SUMMARY[@]} + ${#FAILED_INSTALLATIONS[@]}))
    local successful=${#INSTALLATION_SUMMARY[@]}
    local failed=${#FAILED_INSTALLATIONS[@]}
    
    log_info "Total items processed: $total_attempted"
    log_info "Successful installations: $successful"
    log_info "Failed installations: $failed"
    
    if [ $successful -gt 0 ]; then
        log_info ""
        log_info "✅ Successful installations:"
        for item in "${INSTALLATION_SUMMARY[@]}"; do
            log_info "  $item"
        done
    fi
    
    if [ $failed -gt 0 ]; then
        log_info ""
        log_warn "❌ Failed installations:"
        for item in "${FAILED_INSTALLATIONS[@]}"; do
            log_warn "  $item"
        done
    fi
    
    # Generate detailed report using the same run ID
    generate_version_report "$CONFIG_FILE" "$SCRIPT_DIR/logs/installation-report-$WSL_INSTALL_RUN_ID.txt"
}

# Main function
main() {
    log_info "Starting WSL Installation Script"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Resolve configuration profile
    resolve_config_profile "$CONFIG_ARG"
    
    # Generate install.yaml from resolved profile
    if ! generate_install_yaml; then
        log_error "Failed to generate configuration from profile"
        exit 1
    fi
    
    log_info "Configuration file: $CONFIG_FILE"
    
    # Validate selected sections
    validate_sections
    
    # Validate YAML dependencies (including yq)
    if ! validate_yaml_dependencies; then
        log_error "Failed to set up YAML processing dependencies"
        exit 1
    fi
    
    # Validate configuration
    validate_config
    
    # Read and display metadata
    read_metadata
    
    # Read settings from config
    read_settings
    
    # Setup non-interactive APT environment early to prevent hanging
    log_info "Setting up non-interactive APT environment..."
    setup_noninteractive_apt
    
    # Show dry run notice
    if [ "$DRY_RUN" = "true" ]; then
        log_info "🔍 DRY RUN MODE - No actual installations will be performed"
    fi
    
    # Show force install notice
    if [ "$FORCE_INSTALL" = "true" ]; then
        log_info "🔄 FORCE MODE - All software will be reinstalled"
    fi
    
    # Count total items for progress tracking
    local total_prereqs=$(yq eval '.prerequisites | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
    local total_apt=$(yq eval '.apt_packages | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
    local total_shell=$(yq eval '.shell_setup | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
    local total_custom=$(yq eval '.custom_software | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
    local total_python=$(yq eval '.python_packages | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
    local total_powershell=$(yq eval '.powershell_modules | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
    local total_nix=$(yq eval '.nix_packages | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
    local total_configs=$(yq eval '.configurations | length' "$CONFIG_FILE" 2>/dev/null || echo "0")
    
    # Calculate totals (avoiding null values)
    [ "$total_prereqs" = "null" ] && total_prereqs=0
    [ "$total_apt" = "null" ] && total_apt=0
    [ "$total_shell" = "null" ] && total_shell=0
    [ "$total_custom" = "null" ] && total_custom=0
    [ "$total_python" = "null" ] && total_python=0
    [ "$total_powershell" = "null" ] && total_powershell=0
    [ "$total_nix" = "null" ] && total_nix=0
    [ "$total_configs" = "null" ] && total_configs=0
    
    local total_items=$((total_prereqs + total_apt + total_shell + total_custom + total_python + total_powershell + total_nix + total_configs))
    
    if [ "$total_items" -gt 0 ]; then
        log_info "📊 Installation plan: $total_items total items"
        log_info "   • Prerequisites: $total_prereqs"
        log_info "   • APT packages: $total_apt"
        log_info "   • Shell setup: $total_shell" 
        log_info "   • Custom software: $total_custom"
        log_info "   • Python packages: $total_python"
        log_info "   • PowerShell modules: $total_powershell"
        log_info "   • Nix packages: $total_nix"
        log_info "   • Configurations: $total_configs"
    fi
    
    # Show selected sections if any
    if [ ${#SELECTED_SECTIONS[@]} -gt 0 ]; then
        log_info "Selected sections: ${SELECTED_SECTIONS[*]}"
    fi

    # Execute installation phases
    if should_run_section "prerequisites"; then
        install_prerequisites
    else
        log_info "Skipping prerequisites section (not selected)"
    fi
    
    if should_run_section "apt_packages"; then
        install_apt_packages
    else
        log_info "Skipping apt_packages section (not selected)"
    fi
    
    if should_run_section "shell_setup"; then
        run_shell_setup
    else
        log_info "Skipping shell_setup section (not selected)"
    fi
    
    if should_run_section "custom_software"; then
        install_custom_software
    else
        log_info "Skipping custom_software section (not selected)"
    fi
    
    if should_run_section "python_packages"; then
        install_python_packages
    else
        log_info "Skipping python_packages section (not selected)"
    fi
    
    if should_run_section "powershell_modules"; then
        install_powershell_modules
    else
        log_info "Skipping powershell_modules section (not selected)"
    fi
    
    if should_run_section "nix_packages"; then
        install_nix_packages
    else
        log_info "Skipping nix_packages section (not selected)"
    fi
    
    if should_run_section "configurations"; then
        run_configurations
    else
        log_info "Skipping configurations section (not selected)"
    fi
    
    # Cleanup
    cleanup
    
    # Show summary
    show_summary
    
    # Show related files
    if [ "$DRY_RUN" != "true" ]; then
        show_run_files
    fi
    
    log_info "Installation script completed!"
    
    # Exit with error code if there were failures
    if [ ${#FAILED_INSTALLATIONS[@]} -gt 0 ] && [ "$DRY_RUN" != "true" ]; then
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
