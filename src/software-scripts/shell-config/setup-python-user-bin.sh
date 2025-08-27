#!/bin/bash

# Python User Bin PATH Configuration Script
# Sets up system-wide access to Python user packages installed via pip --user or pipx

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
    log_warn() { echo "[WARN] $1"; }
fi

setup_python_user_bin_path() {
    log_info "Setting up system-wide Python user bin PATH access..."
    
    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo access to set up system-wide configuration"
        return 1
    fi
    
    # Ensure ~/.local/bin directory exists for current user
    if [ ! -d "$HOME/.local/bin" ]; then
        log_info "Creating ~/.local/bin directory for current user"
        mkdir -p "$HOME/.local/bin"
    fi
    
    # Create system-wide profile script
    local system_profile="/etc/profile.d/python-user-bin.sh"
    
    if [ ! -f "$system_profile" ]; then
        log_info "Creating system profile: $system_profile"
        sudo tee "$system_profile" > /dev/null << 'EOF'
#!/bin/bash
# Python user packages binary directory
# This script adds ~/.local/bin to PATH for all users
# Used by pip --user and pipx installations

# Ensure the directory exists
if [ ! -d "$HOME/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
fi

# Add to PATH if not already present
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
EOF
        sudo chmod +x "$system_profile"
        log_success "Created system profile: $system_profile"
    else
        log_info "System profile already exists: $system_profile"
    fi
    
    # Update skeleton files for new users
    setup_skeleton_files
    
    # Update current user's shell files
    setup_current_user_shells
    
    log_success "Python user bin PATH setup completed!"
    log_info "New shells will automatically have access to Python user packages"
    log_info "For current shell, run: source /etc/profile.d/python-user-bin.sh"
}

setup_skeleton_files() {
    log_info "Updating skeleton files for new users..."
    
    # Update skeleton files using environment setup utilities if available
    if command -v update_skeleton_files >/dev/null 2>&1; then
        # Use the standard environment setup approach for bash/profile
        local python_path_config='# Ensure ~/.local/bin directory exists
if [ ! -d "$HOME/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
fi

# Python user packages binary directory
if [ -d "$HOME/.local/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
fi'
        update_skeleton_files "$python_path_config" "Python user packages binary directory"
        
        # Create separate Python configuration for zsh integration
        create_python_zsh_integration
    else
        # Use fallback method for bash/profile only (avoid zsh conflicts)
        update_skeleton_files_fallback
    fi
}

# Create separate Python configuration for zsh integration
create_python_zsh_integration() {
    log_info "Creating Python zsh integration configuration"
    
    # Create a configuration snippet that can be sourced by zsh configurations
    local python_config_dir="/usr/local/share/python"
    local python_config_file="$python_config_dir/python.zsh"
    
    if sudo -n true 2>/dev/null; then
        sudo mkdir -p "$python_config_dir"
        sudo tee "$python_config_file" > /dev/null << 'EOF'
# Ensure ~/.local/bin directory exists
if [ ! -d "$HOME/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
fi

# Python user packages binary directory
if [ -d "$HOME/.local/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
fi
EOF
        sudo chmod 644 "$python_config_file"
        log_info "Created Python configuration at $python_config_file"
        log_info "This will be automatically loaded by the zsh configuration system"
    else
        log_warn "Cannot create system-wide Python configuration (no sudo access)"
    fi
}

update_skeleton_files_fallback() {
    log_info "Updating skeleton files for new users (fallback method)..."
    
    # Ensure skel directory exists
    sudo mkdir -p /etc/skel
    
    # Only update bash/profile files to avoid conflicts with zsh setup
    local skel_files=("/etc/skel/.bashrc" "/etc/skel/.profile")
    
    for skel_file in "${skel_files[@]}"; do
        # Create the skeleton file if it doesn't exist
        if [ ! -f "$skel_file" ]; then
            sudo touch "$skel_file"
            log_info "Created $skel_file"
        fi
        
        # Check if Python user bin PATH configuration already exists
        if ! sudo grep -q "\.local/bin" "$skel_file" 2>/dev/null; then
            echo "" | sudo tee -a "$skel_file" > /dev/null
            echo "# Ensure ~/.local/bin directory exists" | sudo tee -a "$skel_file" > /dev/null
            echo 'if [ ! -d "$HOME/.local/bin" ]; then' | sudo tee -a "$skel_file" > /dev/null
            echo '    mkdir -p "$HOME/.local/bin"' | sudo tee -a "$skel_file" > /dev/null
            echo 'fi' | sudo tee -a "$skel_file" > /dev/null
            echo "" | sudo tee -a "$skel_file" > /dev/null
            echo "# Python user packages binary directory" | sudo tee -a "$skel_file" > /dev/null
            echo 'if [ -d "$HOME/.local/bin" ]; then' | sudo tee -a "$skel_file" > /dev/null
            echo '    case ":$PATH:" in' | sudo tee -a "$skel_file" > /dev/null
            echo '        *":$HOME/.local/bin:"*) ;;' | sudo tee -a "$skel_file" > /dev/null
            echo '        *) export PATH="$HOME/.local/bin:$PATH" ;;' | sudo tee -a "$skel_file" > /dev/null
            echo '    esac' | sudo tee -a "$skel_file" > /dev/null
            echo 'fi' | sudo tee -a "$skel_file" > /dev/null
            log_info "Updated $skel_file with Python user bin PATH"
        else
            log_info "Python user bin PATH already exists in $skel_file"
        fi
    done
    
    # For zsh skeleton, create separate configuration instead of direct modification
    create_python_zsh_integration
}

setup_current_user_shells() {
    log_info "Updating current user's shell configuration files..."
    
    local user_files=("$HOME/.bashrc" "$HOME/.profile")
    
    # Add zshrc if zsh is available
    if command -v zsh >/dev/null 2>&1 && [ -f "$HOME/.zshrc" ]; then
        user_files+=("$HOME/.zshrc")
    fi
    
    for user_file in "${user_files[@]}"; do
        if [ -f "$user_file" ]; then
            # Check if Python user bin PATH configuration already exists
            if ! grep -q "\.local/bin" "$user_file" 2>/dev/null; then
                echo "" >> "$user_file"
                echo "# Ensure ~/.local/bin directory exists" >> "$user_file"
                echo 'if [ ! -d "$HOME/.local/bin" ]; then' >> "$user_file"
                echo '    mkdir -p "$HOME/.local/bin"' >> "$user_file"
                echo 'fi' >> "$user_file"
                echo "" >> "$user_file"
                echo "# Python user packages binary directory" >> "$user_file"
                echo 'if [ -d "$HOME/.local/bin" ]; then' >> "$user_file"
                echo '    case ":$PATH:" in' >> "$user_file"
                echo '        *":$HOME/.local/bin:"*) ;;' >> "$user_file"
                echo '        *) export PATH="$HOME/.local/bin:$PATH" ;;' >> "$user_file"
                echo '    esac' >> "$user_file"
                echo 'fi' >> "$user_file"
                log_info "Updated $user_file with Python user bin PATH"
            else
                log_info "Python user bin PATH already exists in $user_file"
            fi
        fi
    done
    
    # Ensure ~/.local/bin directory exists for current user
    if [ ! -d "$HOME/.local/bin" ]; then
        log_info "Creating ~/.local/bin directory for current user"
        mkdir -p "$HOME/.local/bin"
    fi
    
    # Add to current session if not already present
    if [ -d "$HOME/.local/bin" ]; then
        case ":$PATH:" in
            *":$HOME/.local/bin:"*) 
                log_info "Python user bin directory already in current PATH"
                ;;
            *) 
                export PATH="$HOME/.local/bin:$PATH"
                log_info "Added Python user bin directory to current session PATH"
                ;;
        esac
    fi
}

# Run the setup
setup_python_user_bin_path
