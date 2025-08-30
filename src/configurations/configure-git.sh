#!/bin/bash

# Git Configuration Script
# This script configures git with basic settings and useful aliases

set -e

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/utils"

# Source the installation framework
if [ -f "$UTILS_DIR/installation-framework.sh" ]; then
    source "$UTILS_DIR/installation-framework.sh"
else
    echo "[ERROR] Installation framework not found at $UTILS_DIR/installation-framework.sh"
    exit 1
fi

# Source package manager for apt functions  
if [ -f "$UTILS_DIR/package-manager.sh" ]; then
    source "$UTILS_DIR/package-manager.sh"
else
    echo "[ERROR] Package manager not found at $UTILS_DIR/package-manager.sh"
    exit 1
fi

# Standalone execution support
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    log_info "Running git configuration script in standalone mode"
fi

configure_git() {
    log_info "Configuring git with basic settings..."
    
    # Check if git is installed
    if ! command -v git >/dev/null 2>&1; then
        log_error "git is not installed. Installing git first..."
        update_package_lists
        if ! install_apt_package git latest; then
            log_error "Failed to install git"
            return 1
        fi
        log_success "git installed successfully"
    else
        local git_version
        git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "git is already installed (version: $git_version)"
    fi
    
    # Set basic git configuration if not already set
    configure_git_user_settings
    configure_git_aliases
    configure_git_global_settings
    show_git_configuration
    
    return 0
}

configure_git_user_settings() {
    log_info "Checking git user configuration..."
    
    local user_name
    local user_email
    user_name=$(git config --global user.name 2>/dev/null || echo "")
    user_email=$(git config --global user.email 2>/dev/null || echo "")
    
    if [ -z "$user_name" ]; then
        log_warn "Git user.name not set. Please configure manually with: git config --global user.name 'Your Name'"
        log_info "Example: git config --global user.name 'John Doe'"
    else
        log_info "Git user.name already configured: $user_name"
    fi
    
    if [ -z "$user_email" ]; then
        log_warn "Git user.email not set. Please configure manually with: git config --global user.email 'your.email@example.com'"
        log_info "Example: git config --global user.email 'john.doe@example.com'"
    else
        log_info "Git user.email already configured: $user_email"
    fi
}

configure_git_aliases() {
    log_info "Setting up git aliases..."
    
    # Set useful git aliases
    git config --global alias.st status
    git config --global alias.br branch
    git config --global alias.co checkout
    git config --global alias.cm commit
    git config --global alias.lg "log --oneline --graph --decorate"
    git config --global alias.ll "log --pretty=format:'%h %ad %s (%an)' --date=short"
    git config --global alias.unstage "reset HEAD --"
    git config --global alias.last "log -1 HEAD"
    
    log_info "Git aliases configured:"
    log_info "  git st       -> git status"
    log_info "  git br       -> git branch"
    log_info "  git co       -> git checkout"
    log_info "  git cm       -> git commit"
    log_info "  git lg       -> git log --oneline --graph --decorate"
    log_info "  git ll       -> git log --pretty=format:'%h %ad %s (%an)' --date=short"
    log_info "  git unstage  -> git reset HEAD --"
    log_info "  git last     -> git log -1 HEAD"
}

configure_git_global_settings() {
    log_info "Setting additional git configurations..."
    
    # Use colors in git output
    git config --global color.ui auto
    
    # Set default branch name to main (for new repositories)
    git config --global init.defaultBranch main
    
    # Configure pull behavior
    git config --global pull.rebase false
    
    # Configure line ending handling (appropriate for WSL/Linux)
    git config --global core.autocrlf input
    
    # Set up better diff and merge tools if available
    if command -v nvim >/dev/null 2>&1; then
        git config --global core.editor nvim
        log_info "Set nvim as git editor"
    elif command -v vim >/dev/null 2>&1; then
        git config --global core.editor vim
        log_info "Set vim as git editor"
    elif command -v nano >/dev/null 2>&1; then
        git config --global core.editor nano
        log_info "Set nano as git editor"
    fi
    
    # Configure push behavior
    git config --global push.default simple
    
    # Enable rerere (reuse recorded resolution)
    git config --global rerere.enabled true
    
    log_success "Git global settings configured successfully"
}

show_git_configuration() {
    log_info ""
    log_info "Current git configuration summary:"
    
    # Show user configuration
    local user_name
    local user_email
    user_name=$(git config --global user.name 2>/dev/null || echo "Not set")
    user_email=$(git config --global user.email 2>/dev/null || echo "Not set")
    
    log_info "User Configuration:"
    log_info "  Name:  $user_name"
    log_info "  Email: $user_email"
    log_info ""
    
    # Show some key settings
    log_info "Key Settings:"
    git config --global --list | grep -E "(core\.editor|init\.defaultBranch|pull\.rebase|color\.ui|core\.autocrlf|push\.default)" | while read line; do
        log_info "  $line"
    done
    
    log_info ""
    log_info "To view all git configuration: git config --global --list"
    log_info "To change user settings:"
    log_info "  git config --global user.name 'Your Name'"
    log_info "  git config --global user.email 'your.email@example.com'"
}

# Main execution
main() {
    configure_git
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if main "$@"; then
        log_success "Git configuration completed successfully"
        exit 0
    else
        log_error "Git configuration failed"
        exit 1
    fi
fi
