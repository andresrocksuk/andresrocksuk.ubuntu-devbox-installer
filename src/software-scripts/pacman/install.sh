#!/bin/bash

# Pacman Installation Script for WSL/Linux
# This script attempts to install pacman package manager
# Note: This is primarily for Arch-based systems, but included for completeness

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WSL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities if available (for integration with main installer)
if [ -f "$WSL_DIR/utils/logger.sh" ]; then
    source "$WSL_DIR/utils/logger.sh"
else
    # Standalone logging functions
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_debug() { echo "[DEBUG] $1"; }
fi

# Standalone execution support
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    log_info "Running pacman installation script in standalone mode"
fi

install_pacman() {
    log_info "Starting pacman installation check..."
    
    # Check if pacman is already installed
    if command -v pacman >/dev/null 2>&1; then
        local current_version=$(pacman --version | head -n 1 | awk '{print $3}')
        log_info "Pacman is already installed: $current_version"
        return 0
    fi
    
    # Detect distribution
    local distro=""
    if [ -f /etc/os-release ]; then
        distro=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    fi
    
    log_info "Detected distribution: $distro"
    
    case "$distro" in
        arch|manjaro|artix|endeavouros)
            log_info "Arch-based distribution detected. Pacman should already be available."
            if ! command -v pacman >/dev/null 2>&1; then
                log_error "This is an Arch-based system but pacman is not found. System may be corrupted."
                return 1
            fi
            ;;
        ubuntu|debian)
            log_warn "Ubuntu/Debian detected. Pacman is not the native package manager."
            log_info "Installing pacman as an additional package manager (experimental)..."
            install_pacman_on_debian
            ;;
        fedora|rhel|centos)
            log_warn "Red Hat-based distribution detected. Pacman is not the native package manager."
            log_info "Installing pacman as an additional package manager (experimental)..."
            install_pacman_on_redhat
            ;;
        *)
            log_warn "Unknown or unsupported distribution: $distro"
            log_info "Attempting generic installation..."
            install_pacman_generic
            ;;
    esac
}

install_pacman_on_debian() {
    log_info "Installing pacman on Debian/Ubuntu system..."
    
    # Check prerequisites
    if ! command -v git >/dev/null 2>&1; then
        log_error "git is required but not installed. Please install git first."
        return 1
    fi
    
    # Install build dependencies
    log_info "Installing build dependencies..."
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y build-essential autoconf pkg-config libarchive-dev \
        libssl-dev libgpgme-dev libcurl4-openssl-dev meson >/dev/null 2>&1
    
    # Try to install pacman from package repository first (if available)
    if apt-cache show pacman >/dev/null 2>&1; then
        log_info "Installing pacman from package repository..."
        if sudo apt-get install -y pacman; then
            log_info "Pacman installed from package repository"
            return 0
        else
            log_warn "Failed to install from package repository, trying manual build..."
        fi
    fi
    
    # Build from source as fallback
    build_pacman_from_source
}

install_pacman_on_redhat() {
    log_info "Installing pacman on Red Hat-based system..."
    
    # Install build dependencies
    log_info "Installing build dependencies..."
    sudo yum groupinstall -y "Development Tools" >/dev/null 2>&1
    sudo yum install -y libarchive-devel openssl-devel gpgme-devel \
        curl-devel meson pkg-config >/dev/null 2>&1
    
    # Build from source
    build_pacman_from_source
}

install_pacman_generic() {
    log_warn "Attempting generic pacman installation (may not work on all systems)..."
    build_pacman_from_source
}

build_pacman_from_source() {
    log_info "Building pacman from source..."
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || return 1
    
    # Clone pacman source
    log_info "Cloning pacman source code..."
    if ! git clone https://gitlab.archlinux.org/pacman/pacman.git; then
        log_error "Failed to clone pacman source"
        rm -rf "$temp_dir"
        return 1
    fi
    
    cd pacman || return 1
    
    # Configure and build
    log_info "Configuring build..."
    if ! meson setup build --prefix=/usr/local; then
        log_error "Failed to configure pacman build"
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_info "Building pacman (this may take a while)..."
    if ! meson compile -C build; then
        log_error "Failed to build pacman"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Install
    log_info "Installing pacman..."
    if ! sudo meson install -C build; then
        log_error "Failed to install pacman"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Verify installation
    if command -v pacman >/dev/null 2>&1; then
        local version=$(pacman --version | head -n 1 | awk '{print $3}')
        log_info "Pacman installed successfully from source: $version"
        
        # Create basic configuration if needed
        create_basic_pacman_config
        
        return 0
    else
        log_error "Pacman build completed but command not found"
        return 1
    fi
}

create_basic_pacman_config() {
    log_info "Creating basic pacman configuration..."
    
    # Create pacman configuration directory
    sudo mkdir -p /usr/local/etc/pacman.d
    
    # Create a minimal pacman.conf if it doesn't exist
    if [ ! -f /usr/local/etc/pacman.conf ]; then
        sudo tee /usr/local/etc/pacman.conf > /dev/null << 'EOF'
#
# /usr/local/etc/pacman.conf
#
# Basic pacman configuration
#

[options]
# The following paths are commented out with their default values listed.
# If you wish to use different paths, uncomment and update the paths.
#RootDir     = /
#DBPath      = /usr/local/var/lib/pacman/
#CacheDir    = /usr/local/var/cache/pacman/pkg/
#LogFile     = /usr/local/var/log/pacman.log
#GPGDir      = /usr/local/etc/pacman.d/gnupg/
#HookDir     = /usr/local/etc/pacman.d/hooks/
HoldPkg     = pacman glibc
#XferCommand = /usr/bin/curl -L -C - -f -o %o %u
#XferCommand = /usr/bin/wget --passive-ftp -c -O %o %u
#CleanMethod = KeepInstalled
Architecture = auto

# Pacman won't upgrade packages listed in IgnorePkg and members of IgnoreGroup
#IgnorePkg   =
#IgnoreGroup =

#NoUpgrade   =
#NoExtract   =

# Misc options
#UseSyslog
#Color
#TotalDownload
CheckSpace
#VerbosePkgLists

# By default, pacman accepts packages signed by keys that its local keyring
# trusts (see pacman-key and its man page), as well as unsigned packages.
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional
#RemoteFileSigLevel = Required

# NOTE: This is a custom installation and may not have access to standard Arch repositories
# Add your custom repositories here if needed
#[custom]
#Server = https://your-custom-repo.com/

EOF
        log_info "Created basic pacman configuration"
    fi
    
    # Create database directory
    sudo mkdir -p /usr/local/var/lib/pacman
    sudo mkdir -p /usr/local/var/cache/pacman/pkg
    
    log_warn "Note: Pacman has been installed but may not have access to standard Arch repositories."
    log_warn "You will need to configure appropriate repositories in /usr/local/etc/pacman.conf"
}

# Main execution
if install_pacman; then
    log_info "Pacman installation completed successfully"
    if command -v pacman >/dev/null 2>&1; then
        log_info "Pacman version: $(pacman --version | head -n 1)"
        log_warn "Note: On non-Arch systems, pacman may have limited functionality"
        log_warn "Consider using the native package manager for your distribution"
    fi
    exit 0
else
    log_error "Pacman installation failed"
    log_info "This is normal on non-Arch Linux distributions"
    log_info "Consider using your distribution's native package manager instead"
    exit 1
fi
