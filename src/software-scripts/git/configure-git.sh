#!/bin/bash

# Git Configuration Script
# This script configures git with basic settings and useful aliases

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
    log_info "Running git configuration script in standalone mode"
fi

configure_git() {
    log_info "Configuring git with basic settings..."
    
    # Check if git is installed
    if ! command -v git >/dev/null 2>&1; then
        log_error "git is not installed. Please install git first."
        return 1
    fi
    
    # Set basic git configuration if not already set
    if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
        log_warn "Git user.name not set. Please configure manually with: git config --global user.name 'Your Name'"
    else
        log_info "Git user.name already configured: $(git config --global user.name)"
    fi
    
    if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
        log_warn "Git user.email not set. Please configure manually with: git config --global user.email 'your.email@example.com'"
    else
        log_info "Git user.email already configured: $(git config --global user.email)"
    fi
    
    # Set useful git aliases
    log_info "Setting up git aliases..."
    
    git config --global alias.st status
    git config --global alias.br branch
    git config --global alias.co checkout
    git config --global alias.cm commit
    git config --global alias.lg "log --oneline --graph --decorate"
    
    log_info "Git aliases configured:"
    log_info "  git st   -> git status"
    log_info "  git br   -> git branch"
    log_info "  git co   -> git checkout"
    log_info "  git cm   -> git commit"
    log_info "  git lg   -> git log --oneline --graph --decorate"
    
    # Set some useful global settings
    log_info "Setting additional git configurations..."
    
    # Use colors in git output
    git config --global color.ui auto
    
    # Set default branch name to main (for new repositories)
    git config --global init.defaultBranch main
    
    # Configure pull behavior
    git config --global pull.rebase false
    
    # Set up better diff and merge tools if available
    if command -v nvim >/dev/null 2>&1; then
        git config --global core.editor nvim
        log_info "Set nvim as git editor"
    elif command -v vim >/dev/null 2>&1; then
        git config --global core.editor vim
        log_info "Set vim as git editor"
    fi
    
    # Configure line ending handling
    git config --global core.autocrlf input
    
    # Show current git configuration
    log_info "Current git configuration:"
    git config --global --list | grep -E "(user\.|alias\.|core\.editor|init\.defaultBranch|pull\.rebase|color\.ui|core\.autocrlf)" | while read line; do
        log_info "  $line"
    done
    
    return 0
}

# Main execution
if configure_git; then
    log_info "Git configuration completed successfully"
    exit 0
else
    log_error "Git configuration failed"
    exit 1
fi
