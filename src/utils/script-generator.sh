#!/bin/bash

# script-generator.sh - Utility to generate installation scripts from templates

# Handle being sourced from different directories
if [ -n "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
    if [ "$SCRIPT_DIR" = "${BASH_SOURCE[0]}" ]; then
        SCRIPT_DIR="."
    fi
    SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
else
    SCRIPT_DIR="${0%/*}"
    if [ "$SCRIPT_DIR" = "$0" ]; then
        SCRIPT_DIR="."
    fi
    SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
fi

# Source required utilities
source "$SCRIPT_DIR/logger.sh"
source "$SCRIPT_DIR/security-helpers.sh"

# Template directory
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/../../templates" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/../software-scripts" && pwd)"

# Function to generate a new installation script from template
# Usage: generate_install_script "software_name" "description" ["command_name"] ["version_flag"]
generate_install_script() {
    local software_name="$1"
    local description="$2"
    local command_name="${3:-$software_name}"
    local version_flag="${4:---version}"
    
    # Validate inputs
    if ! validate_package_name "$software_name" >/dev/null; then
        log_error "Invalid software name: $software_name"
        return 1
    fi
    
    if [ -z "$description" ]; then
        log_error "Description cannot be empty"
        return 1
    fi
    
    if ! validate_command_name "$command_name" >/dev/null; then
        log_error "Invalid command name: $command_name"
        return 1
    fi
    
    # Check if template exists
    local template_file="$TEMPLATE_DIR/install-script-template.sh"
    if [ ! -f "$template_file" ]; then
        log_error "Template file not found: $template_file"
        return 1
    fi
    
    # Create software directory
    local software_dir="$SCRIPTS_DIR/$software_name"
    if [ -d "$software_dir" ]; then
        log_warn "Directory already exists: $software_dir"
        read -p "Do you want to overwrite the existing script? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Script generation cancelled"
            return 1
        fi
    else
        mkdir -p "$software_dir"
        log_info "Created directory: $software_dir"
    fi
    
    # Generate script
    local output_file="$software_dir/install.sh"
    local software_name_lowercase
    software_name_lowercase=$(echo "$software_name" | tr '[:upper:]' '[:lower:]')
    
    log_info "Generating installation script for $software_name..."
    
    # Read template and perform substitutions
    local script_content
    script_content=$(cat "$template_file")
    
    # Replace template variables
    script_content=$(echo "$script_content" | sed \
        -e "s/{{SOFTWARE_NAME}}/$software_name/g" \
        -e "s/{{SOFTWARE_DESCRIPTION}}/$description/g" \
        -e "s/{{COMMAND_NAME:-\$SOFTWARE_NAME}}/$command_name/g" \
        -e "s/{{VERSION_FLAG:---version}}/$version_flag/g" \
        -e "s/{{SOFTWARE_NAME_LOWERCASE}}/$software_name_lowercase/g")
    
    # Write to output file
    echo "$script_content" > "$output_file"
    chmod +x "$output_file"
    
    log_success "Generated installation script: $output_file"
    log_info "Please edit the script to implement the actual installation logic"
    
    return 0
}

# Function to validate template variables
# Usage: validate_template_variables "template_file"
validate_template_variables() {
    local template_file="$1"
    
    if [ ! -f "$template_file" ]; then
        log_error "Template file not found: $template_file"
        return 1
    fi
    
    log_info "Validating template variables in: $template_file"
    
    # Check for required template variables
    local required_vars=(
        "{{SOFTWARE_NAME}}"
        "{{SOFTWARE_DESCRIPTION}}"
        "{{SOFTWARE_NAME_LOWERCASE}}"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if ! grep -q "$var" "$template_file"; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required template variables: ${missing_vars[*]}"
        return 1
    fi
    
    log_success "Template validation passed"
    return 0
}

# Function to list available templates
# Usage: list_templates
list_templates() {
    log_info "Available templates in $TEMPLATE_DIR:"
    
    if [ ! -d "$TEMPLATE_DIR" ]; then
        log_error "Template directory not found: $TEMPLATE_DIR"
        return 1
    fi
    
    local templates
    templates=$(find "$TEMPLATE_DIR" -name "*.sh" -type f)
    
    if [ -z "$templates" ]; then
        log_warn "No templates found"
        return 1
    fi
    
    while read -r template; do
        local template_name
        template_name=$(basename "$template" .sh)
        log_info "  - $template_name"
    done <<< "$templates"
    
    return 0
}

# Function to backup existing installation script
# Usage: backup_script "script_path"
backup_script() {
    local script_path="$1"
    
    if [ ! -f "$script_path" ]; then
        return 0  # No backup needed if file doesn't exist
    fi
    
    local backup_path="${script_path}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if cp "$script_path" "$backup_path"; then
        log_info "Created backup: $backup_path"
        return 0
    else
        log_error "Failed to create backup of: $script_path"
        return 1
    fi
}

# Function to refactor existing script to use framework
# Usage: refactor_script_to_framework "script_path"
refactor_script_to_framework() {
    local script_path="$1"
    
    if [ ! -f "$script_path" ]; then
        log_error "Script file not found: $script_path"
        return 1
    fi
    
    # Create backup first
    if ! backup_script "$script_path"; then
        log_error "Failed to create backup, aborting refactor"
        return 1
    fi
    
    log_info "Refactoring script to use installation framework: $script_path"
    
    # Read current script content
    local script_content
    script_content=$(cat "$script_path")
    
    # Check if already using framework
    if echo "$script_content" | grep -q "installation-framework.sh"; then
        log_info "Script already appears to use the installation framework"
        return 0
    fi
    
    # Extract software information from existing script
    local software_name
    software_name=$(basename "$(dirname "$script_path")")
    
    # Extract description from comments (first line with description)
    local description
    description=$(grep -m1 "^# .*installation.*script" "$script_path" | sed 's/^# //; s/ installation script$//')
    if [ -z "$description" ]; then
        description="$software_name installation"
    fi
    
    # Generate new script structure while preserving custom logic
    local temp_script
    temp_script=$(mktemp)
    
    # Write new header with framework
    cat > "$temp_script" << 'EOF'
#!/bin/bash

# {{SOFTWARE_NAME}} installation script
# {{SOFTWARE_DESCRIPTION}}

set -e

# Source the installation framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$(cd "$SCRIPT_DIR/../../utils" && pwd)"

# Source utilities and framework
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
    source "$UTILS_DIR/security-helpers.sh"
else
    # Fallback: source individual utilities
    if [ -f "$UTILS_DIR/logger.sh" ]; then
        source "$UTILS_DIR/logger.sh"
    else
        # Minimal fallback logging functions
        log_info() { echo "[INFO] $1"; }
        log_error() { echo "[ERROR] $1" >&2; }
        log_success() { echo "[SUCCESS] $1"; }
        log_warn() { echo "[WARN] $1"; }
        log_debug() { 
            if [ "${LOG_LEVEL:-INFO}" = "DEBUG" ]; then
                echo "[DEBUG] $1" >&2
            fi
        }
    fi
fi

# Initialize the installation script
if command -v initialize_script >/dev/null 2>&1; then
    initialize_script "{{SOFTWARE_NAME}}" "{{SOFTWARE_DESCRIPTION}}"
fi

# Check for standalone execution
if command -v handle_standalone_execution >/dev/null 2>&1; then
    handle_standalone_execution "{{SOFTWARE_NAME}}"
else
    if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
        log_info "Running {{SOFTWARE_NAME}} installation script in standalone mode"
    fi
fi

EOF
    
    # Extract main installation function and adapt it
    local main_function
    main_function=$(sed -n '/^install_.*() {/,/^}/p' "$script_path")
    
    if [ -n "$main_function" ]; then
        # Add the existing function with framework integration
        echo "# Main installation function (refactored to use framework)" >> "$temp_script"
        echo "$main_function" >> "$temp_script"
    else
        # Create a placeholder if no installation function found
        cat >> "$temp_script" << 'EOF'
# Main installation function
install_{{SOFTWARE_NAME_LOWERCASE}}() {
    log_info "Installing {{SOFTWARE_DESCRIPTION}}..."
    
    # Check if already installed
    if command -v check_already_installed >/dev/null 2>&1; then
        if check_already_installed "{{SOFTWARE_NAME}}" "--version"; then
            return 0
        fi
    fi
    
    # TODO: Implement installation logic from original script
    log_error "Installation logic needs to be manually ported from backup"
    return 1
}
EOF
    fi
    
    # Add execution line
    echo "" >> "$temp_script"
    echo "# Run installation" >> "$temp_script"
    echo "install_{{SOFTWARE_NAME_LOWERCASE}}" >> "$temp_script"
    
    # Perform template substitutions
    local software_name_lowercase
    software_name_lowercase=$(echo "$software_name" | tr '[:upper:]' '[:lower:]')
    
    sed -i \
        -e "s/{{SOFTWARE_NAME}}/$software_name/g" \
        -e "s/{{SOFTWARE_DESCRIPTION}}/$description/g" \
        -e "s/{{SOFTWARE_NAME_LOWERCASE}}/$software_name_lowercase/g" \
        "$temp_script"
    
    # Replace original script
    mv "$temp_script" "$script_path"
    chmod +x "$script_path"
    
    log_success "Script refactored successfully"
    log_warn "Please review and test the refactored script"
    log_warn "You may need to manually port installation logic from the backup"
    
    return 0
}

# Function to show help
show_help() {
    cat << EOF
Script Generator Utility

Usage: $0 COMMAND [OPTIONS]

Commands:
    generate SOFTWARE_NAME DESCRIPTION [COMMAND_NAME] [VERSION_FLAG]
                        Generate new installation script from template
    refactor SCRIPT_PATH
                        Refactor existing script to use framework  
    validate TEMPLATE_PATH
                        Validate template file
    list                List available templates
    help                Show this help message

Examples:
    $0 generate docker "Docker Engine" docker --version
    $0 generate nodejs "Node.js LTS" node --version
    $0 refactor src/software-scripts/git/install.sh
    $0 list

EOF
}

# Main script execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "${1:-help}" in
        "generate")
            if [ $# -lt 3 ]; then
                log_error "Usage: $0 generate SOFTWARE_NAME DESCRIPTION [COMMAND_NAME] [VERSION_FLAG]"
                exit 1
            fi
            generate_install_script "$2" "$3" "$4" "$5"
            ;;
        "refactor")
            if [ $# -lt 2 ]; then
                log_error "Usage: $0 refactor SCRIPT_PATH"
                exit 1
            fi
            refactor_script_to_framework "$2"
            ;;
        "validate")
            if [ $# -lt 2 ]; then
                log_error "Usage: $0 validate TEMPLATE_PATH"
                exit 1
            fi
            validate_template_variables "$2"
            ;;
        "list")
            list_templates
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
fi
