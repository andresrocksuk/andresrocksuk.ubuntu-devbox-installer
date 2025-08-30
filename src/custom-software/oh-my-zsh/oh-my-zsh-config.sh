#!/bin/bash

# Oh My Zsh Shared Configuration
# This file contains the shared configuration used by both the main installation script
# and the new user installation script to ensure consistent setup across all users.

# Oh My Zsh configuration function that can be sourced by other scripts
configure_oh_my_zsh_shared() {
    local user_home="${1:-$HOME}"
    log_info "Configuring Oh My Zsh for user at: $user_home"
    
    # Install plugins if not present
    local plugins_dir="$user_home/.oh-my-zsh/custom/plugins"
    mkdir -p "$plugins_dir"
    
    # Install zsh-autosuggestions
    if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
        if command -v git >/dev/null 2>&1; then
            log_info "Installing zsh-autosuggestions plugin..."
            git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions" >/dev/null 2>&1 || log_warn "Failed to install zsh-autosuggestions"
        fi
    fi
    
    # Install zsh-syntax-highlighting
    if [ ! -d "$plugins_dir/zsh-syntax-highlighting" ]; then
        if command -v git >/dev/null 2>&1; then
            log_info "Installing zsh-syntax-highlighting plugin..."
            git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugins_dir/zsh-syntax-highlighting" >/dev/null 2>&1 || log_warn "Failed to install zsh-syntax-highlighting"
        fi
    fi
    
    # Install zsh-completions
    if [ ! -d "$plugins_dir/zsh-completions" ]; then
        if command -v git >/dev/null 2>&1; then
            log_info "Installing zsh-completions plugin..."
            git clone https://github.com/zsh-users/zsh-completions "$plugins_dir/zsh-completions" >/dev/null 2>&1 || log_warn "Failed to install zsh-completions"
        fi
    fi
    
    # Create comprehensive .zshrc configuration
    create_zshrc_config "$user_home"
    
    log_success "Oh My Zsh configuration completed with plugins and aliases!"
}

# Function to create the standard .zshrc configuration
create_zshrc_config() {
    local user_home="${1:-$HOME}"
    local zshrc="$user_home/.zshrc"
    
    log_info "Creating .zshrc configuration at: $zshrc"
    
    # Backup existing .zshrc if it exists and doesn't contain oh-my-zsh
    if [ -f "$zshrc" ] && ! grep -q "oh-my-zsh" "$zshrc"; then
        cp "$zshrc" "${zshrc}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backed up existing .zshrc"
    fi
    
    cat > "$zshrc" << 'EOF'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="robbyrussell"

# Plugins to load
plugins=(
    git
    docker
    kubectl
    helm
    terraform
    golang
    node
    npm
    python
    pip
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
)

# Load oh-my-zsh
source $ZSH/oh-my-zsh.sh

# User configuration

# Preferred editor
export EDITOR='nvim'

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias glog='git log --oneline --graph --decorate'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dcup='docker-compose up -d'
alias dcdown='docker-compose down'

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'

# Terraform aliases
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'

# Custom functions
function mkcd() {
    mkdir -p "$1" && cd "$1"
}

function extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Load custom configurations if they exist
if [ -f ~/.zshrc.local ]; then
    source ~/.zshrc.local
fi

# Load system-wide tool configurations
for config_file in /usr/local/share/*/*.zsh; do
    if [ -f "$config_file" ]; then
        source "$config_file" 2>/dev/null || true
    fi
done
EOF
    
    log_success ".zshrc configured with oh-my-zsh settings"
}

# Function to create fallback configuration when Oh My Zsh installation fails
create_fallback_zsh_config() {
    local user_home="${1:-$HOME}"
    local zshrc="$user_home/.zshrc"
    
    log_info "Creating fallback zsh configuration at: $zshrc"
    
    cat > "$zshrc" << 'EOF'
# Basic zsh configuration (Oh My Zsh not available)

# Disable zsh new user wizard
DISABLE_AUTO_UPDATE="true"
DISABLE_UPDATE_PROMPT="true"

# Basic prompt with colors
autoload -U colors && colors
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$ '

# History settings
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS

# Aliases (same as Oh My Zsh configuration for consistency)
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias glog='git log --oneline --graph --decorate'

# Custom functions
function mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Enable completion
autoload -U compinit
compinit

# Load system-wide tool configurations
for config_file in /usr/local/share/*/*.zsh; do
    if [ -f "$config_file" ]; then
        source "$config_file" 2>/dev/null || true
    fi
done
EOF
    
    log_success "Basic zsh configuration created with consistent aliases"
}

# Install Oh My Zsh via tarball (more reliable than git clone)
install_oh_my_zsh_tarball() {
    local user_home="${1:-$HOME}"
    
    log_info "Installing Oh My Zsh via tarball for user at: $user_home"
    
    # Force cleanup of any existing partial installations
    log_info "Cleaning up any existing installations..."
    rm -rf "$user_home/.oh-my-zsh" 2>/dev/null || true
    rm -rf "$user_home/.oh-my-zsh.backup" 2>/dev/null || true
    rm -rf "$user_home/.oh-my-zsh.bak" 2>/dev/null || true
    rm -rf "$user_home/ohmyzsh-master" 2>/dev/null || true
    
    # Wait for filesystem operations to complete
    sleep 1
    
    # Verify cleanup was successful
    if [ -d "$user_home/.oh-my-zsh" ]; then
        log_error "Cannot remove existing oh-my-zsh directory. Using basic zsh configuration."
        create_fallback_zsh_config "$user_home"
        return 1
    fi
    
    # Check prerequisites
    if ! command -v curl >/dev/null 2>&1; then
        log_error "Curl not available. Installing basic zsh configuration."
        create_fallback_zsh_config "$user_home"
        return 1
    fi
    
    # Test network connectivity
    log_info "Testing network connectivity..."
    for i in 1 2 3; do
        if curl -Is --connect-timeout 10 --max-time 30 https://github.com >/dev/null 2>&1; then
            log_info "Network connectivity confirmed."
            break
        else
            log_warn "Network test attempt $i failed."
            if [ $i -eq 3 ]; then
                log_error "Network connectivity issues. Installing basic zsh configuration."
                create_fallback_zsh_config "$user_home"
                return 1
            fi
            sleep 2
        fi
    done
    
    # Install Oh My Zsh via tarball
    log_info "Installing Oh My Zsh via tarball download..."
    TEMP_DIR=$(mktemp -d)
    local original_dir=$(pwd)
    cd "$TEMP_DIR"
    
    # Download with retries
    DOWNLOAD_SUCCESS=false
    for attempt in 1 2 3; do
        log_info "Download attempt $attempt..."
        if timeout 60 curl -fsSL --connect-timeout 10 --max-time 120 https://github.com/ohmyzsh/ohmyzsh/archive/master.tar.gz -o oh-my-zsh.tar.gz; then
            if tar -xzf oh-my-zsh.tar.gz 2>/dev/null; then
                DOWNLOAD_SUCCESS=true
                break
            fi
        fi
        sleep 2
    done
    
    if [ "$DOWNLOAD_SUCCESS" = true ] && [ -d "ohmyzsh-master" ]; then
        if mv "ohmyzsh-master" "$user_home/.oh-my-zsh" 2>/dev/null; then
            cd "$original_dir"
            rm -rf "$TEMP_DIR"
            
            if [ -f "$user_home/.oh-my-zsh/oh-my-zsh.sh" ]; then
                log_success "Oh My Zsh installation successful!"
                configure_oh_my_zsh_shared "$user_home"
                return 0
            fi
        fi
    fi
    
    # Clean up and create fallback
    cd "$original_dir"
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    rm -rf "$user_home/.oh-my-zsh" 2>/dev/null || true
    log_error "Oh My Zsh installation failed. Creating basic zsh configuration..."
    create_fallback_zsh_config "$user_home"
    return 1
}

# Fallback logging functions if not already defined
if ! command -v log_info >/dev/null 2>&1; then
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warn() { echo "[WARN] $1"; }
fi
