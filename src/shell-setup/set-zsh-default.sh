#!/bin/bash

# Set Zsh as Default Shell Configuration Script
# This script configures zsh as the default shell for current and new users

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/utils"

# Source utilities if available (for integration with main installer)
if [ -f "$UTILS_DIR/logger.sh" ]; then
    source "$UTILS_DIR/logger.sh"
else
    # Standalone logging functions
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_debug() { echo "[DEBUG] $1"; }
fi

# Standalone execution support
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    log_info "Running zsh default shell configuration script in standalone mode"
fi

configure_zsh_default() {
    log_info "Configuring zsh as default shell..."
    
    # Check if zsh is installed
    if ! command -v zsh >/dev/null 2>&1; then
        log_error "zsh is not installed. Please install zsh first."
        return 1
    fi
    
    # Set zsh as default shell for current user
    if [ "$SHELL" != "$(which zsh)" ]; then
        log_info "Setting zsh as default shell for current user..."
        chsh -s $(which zsh)
        log_info "Default shell changed to zsh for current user. Please restart your session."
    else
        log_info "zsh is already the default shell for current user"
    fi
    
    # Set zsh as default shell for new users by modifying /etc/default/useradd
    if [ -f /etc/default/useradd ]; then
        if ! grep -q "^SHELL=/usr/bin/zsh" /etc/default/useradd; then
            sudo sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd
            log_info "Default shell for new users set to zsh in /etc/default/useradd"
        else
            log_info "Default shell for new users already set to zsh in /etc/default/useradd"
        fi
    else
        # Create the file if it doesn't exist
        echo "SHELL=/usr/bin/zsh" | sudo tee -a /etc/default/useradd > /dev/null
        log_info "Created /etc/default/useradd with zsh as default shell"
    fi
    
    # Also ensure /etc/adduser.conf uses zsh (Ubuntu/Debian specific)
    if [ -f /etc/adduser.conf ]; then
        if ! grep -q "^DSHELL=" /etc/adduser.conf; then
            echo "DSHELL=/usr/bin/zsh" | sudo tee -a /etc/adduser.conf > /dev/null
            log_info "Added zsh as default shell in /etc/adduser.conf"
        else
            sudo sed -i 's|^DSHELL=.*|DSHELL=/usr/bin/zsh|' /etc/adduser.conf
            log_info "Updated default shell to zsh in /etc/adduser.conf"
        fi
    fi
    
    # Create a skeleton .zshrc for new users in /etc/skel
    create_skeleton_zshrc
    
    # Create global zsh configuration to disable newuser wizard
    create_global_zsh_config
    
    # Fix any existing users that might not have .zshrc
    fix_existing_users
    
    return 0
}

create_skeleton_zshrc() {
    log_info "Creating skeleton .zshrc for new users..."
    
    sudo mkdir -p /etc/skel
    
    # Always create/overwrite the skeleton .zshrc to ensure correct configuration
    log_info "Creating proper .zshrc skeleton file (overwriting any existing file)..."
    sudo tee /etc/skel/.zshrc > /dev/null << 'EOF'
# Disable zsh new user wizard
DISABLE_AUTO_UPDATE="true"
DISABLE_UPDATE_PROMPT="true"

# Install Oh My Zsh on first login if not present
if [ ! -d "$HOME/.oh-my-zsh" ] && [ -f "/usr/local/bin/install-oh-my-zsh-user.sh" ]; then
  echo "Setting up Oh My Zsh for first time use..."
  if /usr/local/bin/install-oh-my-zsh-user.sh; then
    # Installation successful, reload the new configuration
    echo "Oh My Zsh setup completed. Reloading configuration..."
    exec zsh
  else
    echo "Oh My Zsh installation failed, continuing with basic zsh configuration."
  fi
fi

# Oh My Zsh configuration (if installed and working)
if [ -d "$HOME/.oh-my-zsh" ] && [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
  export ZSH="$HOME/.oh-my-zsh"
  ZSH_THEME="robbyrussell"
  plugins=(git)
  source $ZSH/oh-my-zsh.sh
else
  # Basic zsh configuration if oh-my-zsh is not available or broken
  autoload -U colors && colors
  PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ '
  
  # History settings
  HISTSIZE=1000
  SAVEHIST=1000
  HISTFILE=~/.zsh_history
  setopt SHARE_HISTORY
  setopt APPEND_HISTORY
  setopt HIST_IGNORE_DUPS
  
  # Enable completion
  autoload -U compinit
  compinit
fi

# Custom aliases
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Load system-wide tool configurations
for config_file in /usr/local/share/*/*.zsh; do
    if [ -f "$config_file" ]; then
        source "$config_file" 2>/dev/null || true
    fi
done
EOF
        log_info "Created skeleton .zshrc for new users in /etc/skel"
    
    # Also create a .zshenv file to disable the newuser wizard globally
    if [ ! -f /etc/skel/.zshenv ]; then
        sudo tee /etc/skel/.zshenv > /dev/null << 'EOF'
# Disable zsh new user configuration wizard
DISABLE_AUTO_UPDATE="true"
EOF
        log_info "Created skeleton .zshenv for new users in /etc/skel"
    else
        log_info "Skeleton .zshenv already exists in /etc/skel"
    fi
}

create_global_zsh_config() {
    log_info "Creating global zsh configuration..."
    
    sudo mkdir -p /etc/zsh
    if [ ! -f /etc/zsh/zshenv ]; then
        sudo tee /etc/zsh/zshenv > /dev/null << 'EOF'
# Disable zsh new user wizard globally
DISABLE_AUTO_UPDATE="true"
EOF
        log_info "Created global zsh configuration to disable newuser wizard"
    else
        log_info "Global zsh configuration already exists"
    fi
}

fix_existing_users() {
    log_info "Checking existing users for zsh configuration..."
    
    # Fix any existing users that might not have .zshrc
    # Copy skeleton files to any existing users with zsh but no .zshrc
    for user_home in /home/*; do
        if [ -d "$user_home" ] && [ "$(basename "$user_home")" != "*" ]; then
            user_name=$(basename "$user_home")
            # Check if user_name is not empty and valid
            if [ -n "$user_name" ]; then
                user_shell=$(getent passwd "$user_name" 2>/dev/null | cut -d: -f7)
                # Check if user_shell is not empty and contains zsh
                if [ -n "$user_shell" ] && [[ "$user_shell" == *"zsh"* ]] && [ ! -f "$user_home/.zshrc" ]; then
                    sudo cp /etc/skel/.zshrc "$user_home/.zshrc" 2>/dev/null || true
                    sudo cp /etc/skel/.zshenv "$user_home/.zshenv" 2>/dev/null || true
                    # Only change ownership if user_name is valid
                    if id "$user_name" >/dev/null 2>&1; then
                        sudo chown "$user_name:$user_name" "$user_home/.zshrc" "$user_home/.zshenv" 2>/dev/null || true
                    fi
                    log_info "Copied zsh configuration to existing user: $user_name"
                fi
            fi
        fi
    done
}

# Main execution
if configure_zsh_default; then
    log_info "Zsh default shell configuration completed successfully"
    exit 0
else
    log_error "Zsh default shell configuration failed"
    exit 1
fi
