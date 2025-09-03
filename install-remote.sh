#!/bin/bash

# install-remote.sh - Remote Ubuntu DevBox Installer for Linux/WSL
# This script downloads the latest version from GitHub and runs the installation

set -e  # Exit on any error

# Script version
SCRIPT_VERSION="1.0.0"

# Default settings
BRANCH_NAME="main"
FORCE_INSTALL=false
DRY_RUN=false
RUN_APT_UPGRADE=false
SELECTED_SECTIONS=()
CONFIG_FILE=""
LOG_LEVEL=""
TEMP_DIR=""
EXTRACTED_DIR=""
CLEANUP_ON_EXIT=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to log colored messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_section() {
    echo -e "${CYAN}[SECTION]${NC} $1"
}

# Function to display help
show_help() {
    cat << EOF
${CYAN}Ubuntu DevBox Remote Installer${NC}

${GREEN}BASIC USAGE:${NC}
    curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash

${GREEN}ADVANCED USAGE:${NC}
    # Download and run with parameters
    curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash -s -- [OPTIONS]
    
    # Or download, make executable, and run
    curl -sSL -o install-remote.sh "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh"
    chmod +x install-remote.sh
    ./install-remote.sh [OPTIONS]

${GREEN}OPTIONS:${NC}
    -h, --help          Show this help message
    -f, --force         Force reinstallation of all software
    -d, --dry-run       Show what would be installed without actually installing
    --run-apt-upgrade   Run apt-get upgrade after apt-get update (default: false)
    -l, --log-level     Set log level (DEBUG, INFO, WARN, ERROR)
    -c, --config        Specify custom config file or URL (default: install.yaml)
    -s, --sections      Specify which sections to run (comma-separated): 
                        prerequisites,apt_packages,shell_setup,custom_software,python_packages,powershell_modules,nix_packages,configurations
    -b, --branch        Specify the branch name to use from the GitHub repository (default: "main")
    -v, --version       Show script version
    --no-cleanup        Keep temporary files after installation (useful for debugging)

${GREEN}EXAMPLES:${NC}
    # Basic installation
    curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash

    # Force reinstall everything
    curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash -s -- --force

    # Install only specific sections
    curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash -s -- --sections "prerequisites,apt_packages"

    # Use custom configuration from URL
    curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash -s -- --config "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/refs/heads/main/examples/minimal-dev.yaml"

    # Dry run to see what would be installed
    curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-remote.sh" | bash -s -- --dry-run

    # Use development branch
    curl -sSL "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/dev/install-remote.sh" | bash -s -- --branch "dev"

EOF
}

# Function to validate input parameters
validate_parameter() {
    local param_name="$1"
    local param_value="$2"
    local validation_pattern="$3"
    local error_message="$4"
    
    if [[ "$param_value" =~ $validation_pattern ]]; then
        return 0
    else
        log_error "$error_message: $param_value"
        return 1
    fi
}

# Function to sanitize branch name
sanitize_branch_name() {
    local branch="$1"
    # Allow alphanumeric, hyphens, underscores, forward slashes, and dots
    if validate_parameter "branch" "$branch" "^[a-zA-Z0-9._/-]+$" "Invalid branch name"; then
        echo "$branch"
        return 0
    else
        return 1
    fi
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
                if [ -z "$2" ]; then
                    log_error "Log level value required"
                    exit 1
                fi
                if validate_parameter "log-level" "$2" "^(DEBUG|INFO|WARN|ERROR)$" "Invalid log level"; then
                    LOG_LEVEL="$2"
                    shift 2
                else
                    exit 1
                fi
                ;;
            -c|--config)
                if [ -z "$2" ]; then
                    log_error "Config value required"
                    exit 1
                fi
                # Allow HTTPS URLs, local file paths, and YAML files
                local config_pattern="^(https://[a-zA-Z0-9._/-]+|[a-zA-Z0-9._/-]+\.ya?ml|[a-zA-Z0-9._/-]+)$"
                if validate_parameter "config" "$2" "$config_pattern" "Invalid config parameter"; then
                    CONFIG_FILE="$2"
                    shift 2
                else
                    exit 1
                fi
                ;;
            -s|--sections)
                if [ -z "$2" ]; then
                    log_error "Sections value required"
                    exit 1
                fi
                if validate_parameter "sections" "$2" "^[a-zA-Z_,]+$" "Invalid sections parameter"; then
                    IFS=',' read -ra SELECTED_SECTIONS <<< "$2"
                    shift 2
                else
                    exit 1
                fi
                ;;
            -b|--branch)
                if [ -z "$2" ]; then
                    log_error "Branch name required"
                    exit 1
                fi
                if BRANCH_NAME=$(sanitize_branch_name "$2"); then
                    shift 2
                else
                    exit 1
                fi
                ;;
            -v|--version)
                echo "Ubuntu DevBox Remote Installer v$SCRIPT_VERSION"
                exit 0
                ;;
            --no-cleanup)
                CLEANUP_ON_EXIT=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Function to check if required tools are available
check_prerequisites() {
    log_section "🔍 Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for curl or wget
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        missing_tools+=("curl or wget")
    fi
    
    # Check for unzip
    if ! command -v unzip >/dev/null 2>&1; then
        missing_tools+=("unzip")
    fi
    
    # Check for tar (alternative to unzip)
    if ! command -v tar >/dev/null 2>&1; then
        missing_tools+=("tar")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing tools and try again:"
        log_info "  Ubuntu/Debian: sudo apt update && sudo apt install curl unzip"
        log_info "  CentOS/RHEL: sudo yum install curl unzip"
        log_info "  Alpine: sudo apk add curl unzip"
        exit 1
    fi
    
    log_success "All prerequisites are available"
}

# Function to download file with fallback
download_file() {
    local url="$1"
    local output_file="$2"
    
    if command -v curl >/dev/null 2>&1; then
        log_info "Downloading with curl: $url"
        if curl -sSL "$url" -o "$output_file"; then
            return 0
        else
            log_error "Failed to download with curl"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        log_info "Downloading with wget: $url"
        if wget -q "$url" -O "$output_file"; then
            return 0
        else
            log_error "Failed to download with wget"
            return 1
        fi
    else
        log_error "Neither curl nor wget available for download"
        return 1
    fi
}

# Function to create temporary directory
create_temp_directory() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    TEMP_DIR="/tmp/ubuntu-devbox-installer-$timestamp"
    
    log_info "📁 Creating temporary directory: $TEMP_DIR"
    
    if mkdir -p "$TEMP_DIR"; then
        log_success "Temporary directory created successfully"
        return 0
    else
        log_error "Failed to create temporary directory"
        return 1
    fi
}

# Function to cleanup temporary files
cleanup_temp_files() {
    if [ "$CLEANUP_ON_EXIT" = "true" ] && [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        log_info "🧹 Cleaning up temporary files..."
        if rm -rf "$TEMP_DIR"; then
            log_success "Cleanup completed"
        else
            log_warn "Warning: Could not clean up temporary directory: $TEMP_DIR"
        fi
    elif [ "$CLEANUP_ON_EXIT" = "false" ]; then
        log_info "💾 Temporary files preserved at: $TEMP_DIR"
    fi
}

# Function to download and extract repository
download_and_extract_repository() {
    log_section "⬇️  Downloading Ubuntu DevBox Installer from GitHub..."
    
    # Prepare URLs and paths
    local branch_clean="${BRANCH_NAME//\//-}"
    local zipUrl="https://github.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/archive/refs/heads/$BRANCH_NAME.zip"
    local zipPath="$TEMP_DIR/$branch_clean.zip"
    local extractedDir="$TEMP_DIR/andresrocksuk.ubuntu-devbox-installer-$branch_clean"
    
    log_info "Repository URL: $zipUrl"
    log_info "Branch: $BRANCH_NAME"
    
    # Download the repository
    if ! download_file "$zipUrl" "$zipPath"; then
        log_error "Failed to download repository from GitHub"
        return 1
    fi
    
    log_success "Download completed successfully"
    
    # Extract the archive
    log_info "📦 Extracting archive..."
    
    if command -v unzip >/dev/null 2>&1; then
        if unzip -q "$zipPath" -d "$TEMP_DIR"; then
            log_success "Archive extracted successfully with unzip"
        else
            log_error "Failed to extract archive with unzip"
            return 1
        fi
    else
        log_error "unzip command not available"
        return 1
    fi
    
    # Verify extracted directory
    if [ ! -d "$extractedDir" ]; then
        log_error "Extracted directory not found: $extractedDir"
        return 1
    fi
    
    # Verify install.sh exists
    if [ ! -f "$extractedDir/src/install.sh" ]; then
        log_error "install.sh not found in extracted repository"
        return 1
    fi
    
    # Make install.sh executable
    chmod +x "$extractedDir/src/install.sh"
    
    # Make all utility scripts executable
    find "$extractedDir/src" -name "*.sh" -type f -exec chmod +x {} \;
    
    log_success "Repository extracted and prepared successfully"
    
    # Return the extracted directory path via a global variable to avoid output pollution
    EXTRACTED_DIR="$extractedDir"
    return 0
}

# Function to build installation arguments
build_install_arguments() {
    local args=()
    
    if [ "$FORCE_INSTALL" = "true" ]; then
        args+=("--force")
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        args+=("--dry-run")
    fi
    
    if [ "$RUN_APT_UPGRADE" = "true" ]; then
        args+=("--run-apt-upgrade")
    fi
    
    if [ -n "$LOG_LEVEL" ]; then
        args+=("--log-level" "$LOG_LEVEL")
    fi
    
    if [ -n "$CONFIG_FILE" ]; then
        args+=("--config" "$CONFIG_FILE")
    fi
    
    if [ ${#SELECTED_SECTIONS[@]} -gt 0 ]; then
        local sections_str=$(IFS=','; echo "${SELECTED_SECTIONS[*]}")
        args+=("--sections" "$sections_str")
    fi
    
    echo "${args[@]}"
}

# Function to run the installation
run_installation() {
    local extracted_dir="$1"
    local install_script="$extracted_dir/src/install.sh"
    
    log_section "🚀 Starting Ubuntu DevBox installation..."
    
    # Build arguments array
    local install_args
    install_args=($(build_install_arguments))
    
    log_info "Installation script: $install_script"
    if [ ${#install_args[@]} -gt 0 ]; then
        log_info "Arguments: ${install_args[*]}"
    else
        log_info "Arguments: (none - using defaults)"
    fi
    
    # Change to the src directory to ensure relative paths work correctly
    cd "$extracted_dir/src"
    
    # Execute the installation script
    if [ ${#install_args[@]} -gt 0 ]; then
        bash ./install.sh "${install_args[@]}"
    else
        bash ./install.sh
    fi
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_success "🎉 Ubuntu DevBox installation completed successfully!"
    else
        log_error "❌ Installation completed with errors (exit code: $exit_code)"
        log_info "Check the installation logs for details"
    fi
    
    return $exit_code
}

# Main installation function
main() {
    local current_dir=$(pwd)
    
    # Set up cleanup trap
    trap cleanup_temp_files EXIT
    
    log_section "🚀 Ubuntu DevBox Remote Installer"
    log_info "========================================"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check prerequisites
    check_prerequisites
    
    # Create temporary directory
    if ! create_temp_directory; then
        exit 1
    fi
    
    # Download and extract repository
    if ! download_and_extract_repository; then
        exit 1
    fi
    
    # Run the installation
    if ! run_installation "$EXTRACTED_DIR"; then
        exit 1
    fi
    
    # Return to original directory
    cd "$current_dir"
    
    log_success "🎉 Remote installation process completed!"
}

# Only run main if script is executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi