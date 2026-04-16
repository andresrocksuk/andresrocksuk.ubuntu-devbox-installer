#!/bin/bash

# Azure DevOps CLI Extension Installation Script
# This script installs the Azure DevOps extension for Azure CLI

# Get script directory for reliable path resolution
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/../../utils"
SHARED_EXTENSION_DIR="${AZURE_DEVOPS_EXTENSION_DIR:-/usr/local/share/azure-cli/cliextensions}"
NATIVE_AZ_PATH="${AZURE_DEVOPS_NATIVE_AZ_PATH:-/usr/bin/az}"
AZ_WRAPPER_PATH="${AZURE_DEVOPS_AZ_WRAPPER_PATH:-/usr/local/bin/az}"
PROFILE_SCRIPT_PATH="${AZURE_DEVOPS_PROFILE_SCRIPT_PATH:-/etc/profile.d/azure-cli-extensions.sh}"
ENV_CONFIG_PATH="${AZURE_DEVOPS_ENV_CONFIG_PATH:-/etc/environment.d/azure-cli-extensions.conf}"

# Source installation framework
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
else
    echo "Error: installation-framework.sh not found at $UTILS_DIR/installation-framework.sh"
    exit 1
fi

# Enable error handling
set -e

run_shared_az() {
    AZURE_EXTENSION_DIR="$SHARED_EXTENSION_DIR" "$NATIVE_AZ_PATH" "$@"
}

ensure_shared_extension_dir() {
    log_info "Ensuring shared Azure CLI extension directory exists: $SHARED_EXTENSION_DIR"

    sudo mkdir -p "$SHARED_EXTENSION_DIR"
    sudo chmod 755 "$SHARED_EXTENSION_DIR"
}

configure_shared_extension_environment() {
    log_info "Configuring shared Azure CLI extension environment..."

    sudo mkdir -p "$(dirname "$PROFILE_SCRIPT_PATH")"
    sudo tee "$PROFILE_SCRIPT_PATH" > /dev/null << EOF
#!/bin/bash
export AZURE_EXTENSION_DIR="$SHARED_EXTENSION_DIR"
EOF
    sudo chmod 644 "$PROFILE_SCRIPT_PATH"

    sudo mkdir -p "$(dirname "$ENV_CONFIG_PATH")"
    sudo tee "$ENV_CONFIG_PATH" > /dev/null << EOF
AZURE_EXTENSION_DIR=$SHARED_EXTENSION_DIR
EOF
    sudo chmod 644 "$ENV_CONFIG_PATH"

    export AZURE_EXTENSION_DIR="$SHARED_EXTENSION_DIR"
}

create_az_wrapper() {
    log_info "Creating Azure CLI wrapper at $AZ_WRAPPER_PATH"

    sudo mkdir -p "$(dirname "$AZ_WRAPPER_PATH")"
    sudo tee "$AZ_WRAPPER_PATH" > /dev/null << EOF
#!/bin/bash
if [ -z "\${AZURE_EXTENSION_DIR:-}" ]; then
    export AZURE_EXTENSION_DIR="$SHARED_EXTENSION_DIR"
fi
exec "$NATIVE_AZ_PATH" "\$@"
EOF
    sudo chmod 755 "$AZ_WRAPPER_PATH"
}

get_shared_extension_version() {
    run_shared_az extension show --name azure-devops --query version -o tsv 2>/dev/null || true
}

verify_shared_extension_installation() {
    local version
    version="$(get_shared_extension_version)"

    if [ -n "$version" ] && [ "$version" != "null" ]; then
        log_success "Azure DevOps CLI extension available from shared directory: $version"
        return 0
    fi

    log_error "Azure DevOps CLI extension is not available from the shared directory"
    return 1
}

# Main installation function
install_azure_devops_cli() {
    log_section "Installing Azure DevOps CLI Extension"
    
    # Check if Azure CLI is installed natively in WSL
    if [ ! -f "$NATIVE_AZ_PATH" ]; then
        log_error "Native Azure CLI is required but not installed in WSL"
        log_info "Please install Azure CLI natively in WSL first"
        return 1
    fi

    # Ensure we use the native Azure CLI
    export PATH="$(dirname "$NATIVE_AZ_PATH"):$PATH"

    local azure_cli_version
    azure_cli_version=$(get_command_version "az" "version")
    log_info "Azure CLI found: $azure_cli_version"

    ensure_shared_extension_dir
    configure_shared_extension_environment
    create_az_wrapper

    # Check if Azure DevOps extension is already installed
    local current_version
    current_version="$(get_shared_extension_version)"

    if [ -n "$current_version" ] && [ "$current_version" != "null" ]; then
        local current_version
        log_info "Azure DevOps CLI extension already installed: $current_version"
        
        # Check for updates
        log_info "Checking for Azure DevOps CLI extension updates..."
        if run_shared_az extension update --name azure-devops >/dev/null 2>&1; then
            local new_version
            new_version="$(get_shared_extension_version)"
            if [ "$current_version" != "$new_version" ]; then
                log_success "Azure DevOps CLI extension upgraded from $current_version to $new_version"
            else
                log_info "Azure DevOps CLI extension is already up to date"
            fi
        else
            log_warn "Failed to check for Azure DevOps CLI extension updates"
        fi

        verify_shared_extension_installation
        return 0
    fi

    log_info "Installing Azure DevOps CLI extension..."

    # Install the Azure DevOps extension
    if run_shared_az extension add --name azure-devops >/dev/null 2>&1; then
        local version
        version="$(get_shared_extension_version)"
        sudo chmod -R a+rX "$SHARED_EXTENSION_DIR"

        if ! verify_shared_extension_installation; then
            return 1
        fi

        log_success "Azure DevOps CLI extension installed successfully: $version"
        
        # Show basic usage info
        log_info "To get started with Azure DevOps CLI:"
        log_info "  az login                                    # Login to Azure"
        log_info "  az devops configure --defaults organization=<org-url>  # Set default organization"
        log_info "  az devops project list                      # List projects"
        log_info "  az repos list                               # List repositories"
        log_info "  az pipelines list                           # List pipelines"
        log_info "  az devops --help                            # Show help"
        log_info "Documentation: https://docs.microsoft.com/azure/devops/cli/"
        return 0
    else
        log_error "Azure DevOps CLI extension installation failed"
        return 1
    fi
}

# Execute installation
install_azure_devops_cli "$@"
