#!/bin/bash

# WSL User Setup Script
# This script helps create a new default user for WSL, similar to the first-run experience

echo "=============================================="
echo "WSL User Setup"
echo "=============================================="
echo

# Function to validate username
validate_username() {
    local username="$1"
    
    # Check if username is empty
    if [[ -z "$username" ]]; then
        echo "Error: Username cannot be empty"
        return 1
    fi
    
    # Check if username already exists
    if id "$username" >/dev/null 2>&1; then
        echo "Error: User '$username' already exists"
        return 1
    fi
    
    # Check username format (alphanumeric, starts with letter, no special chars except -)
    if [[ ! "$username" =~ ^[a-z][a-z0-9-]*$ ]]; then
        echo "Error: Username must start with a letter and contain only lowercase letters, numbers, and hyphens"
        return 1
    fi
    
    # Check username length
    if [[ ${#username} -gt 32 ]]; then
        echo "Error: Username must be 32 characters or less"
        return 1
    fi
    
    return 0
}

# Prompt for username
while true; do
    echo -n "Enter username for the new default user: "
    read username
    
    if validate_username "$username"; then
        break
    fi
    echo
done

echo
echo "Creating user '$username'..."

# Create the user with home directory and bash shell
if useradd --create-home "$username"; then
    echo "User '$username' created successfully"
else
    echo "Error: Failed to create user '$username'"
    exit 1
fi

# Set password for the user
echo
echo "Setting password for user '$username':"
while ! passwd "$username"; do
    echo "Password setting failed. Please try again."
done

# Add user to sudo group
if usermod -aG sudo "$username"; then
    echo "User '$username' added to sudo group"
else
    echo "Warning: Failed to add user '$username' to sudo group"
fi

# Set as default WSL user
echo
echo "Setting '$username' as the default WSL user..."
if command -v wsl.exe >/dev/null 2>&1; then
    # We're running inside WSL, exit and let the user run the command from Windows
    echo "Please run the following command from Windows PowerShell or Command Prompt:"
    echo "wsl --manage Ubuntu-24.04 --set-default-user $username"
    echo
    echo "Then restart WSL by running: wsl --terminate Ubuntu-24.04"
else
    echo "Cannot set default user from within WSL. Please run from Windows:"
    echo "wsl --manage Ubuntu-24.04 --set-default-user $username"
fi

echo
echo "=============================================="
echo "User setup completed!"
echo "=============================================="
echo "Username: $username"
echo "Home directory: /home/$username"
echo "Shell: /bin/bash"
echo "Sudo access: Yes"
echo
echo "Note: Homebrew is available via the 'brew' command"
echo "Example: brew install package-name"
echo "=============================================="
