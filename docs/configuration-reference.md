# Configuration Reference

This document provides a comprehensive reference for configuring the WSL Ubuntu DevBox Installer using configuration profiles and YAML configuration files.

## Configuration Profile System

The installer uses a configuration profile system that allows you to switch between different installation configurations easily.

### Configuration Sources

- **Profile Names**: Use just the filename (e.g., `"minimal-install.yaml"`) to auto-resolve from `src/config-profiles/`
- **Relative Paths**: Use paths like `"src/config-profiles/minimal-install.yaml"` or `"examples/data-science.yaml"`
- **Absolute Paths**: Full system paths to configuration files
- **Remote URLs**: HTTPS URLs to remote configuration files

### Built-in Profiles

The installer includes several pre-configured profiles:

- **`full-install.yaml`**: Complete development environment with all features (default)
- **`minimal-install.yaml`**: Minimal installation with basic development tools

### Profile Resolution

The installer resolves configuration profiles in the following order:

1. **URL**: If the config starts with `https://`, it's treated as a remote URL
2. **Absolute Path**: If the config starts with `/`, it's treated as an absolute path
3. **Profile Name**: If the config is just a filename (e.g., `minimal-install.yaml`), it's resolved from `src/config-profiles/`
4. **Relative Path**: Otherwise, it's resolved relative to the project root

### PowerShell Parameter Reference

#### Configuration Parameters

- `-Config <string>`: Configuration profile name, path, or URL
  - Profile names: `"minimal-install.yaml"`
  - Relative paths: `"src/config-profiles/minimal-install.yaml"`
  - Absolute paths: `"/path/to/config.yaml"`
  - Remote URLs: `"https://example.com/config.yaml"`
- `-AutoInstall`: Run without user prompts (for automation)
- `-ResetWSL`: Reset WSL distribution before installation (destructive operation)
- `-RunDirect`: Execute directly without copying to temp directory
- `-Sections <string[]>`: Specify specific sections to install

#### Examples

```powershell
# Use minimal profile
.\install-wsl.ps1 -AutoInstall -Config "minimal-install.yaml"

# Use full profile with explicit path
.\install-wsl.ps1 -AutoInstall -Config "src/config-profiles/full-install.yaml"

# Use remote configuration
.\install-wsl.ps1 -AutoInstall -Config "https://example.com/config.yaml"

# Default behavior (uses full-install.yaml)
.\install-wsl.ps1 -AutoInstall
```

## YAML Schema Overview

The configuration system uses a structured YAML format to define all aspects of your development environment. Here's the complete schema:

```yaml
# Metadata section (Enhanced with support URL)
metadata:
  name: "Environment Name"
  description: "Description of the environment"
  version: "1.0.0"
  target_os: "ubuntu-24.04"
  author: "Author Name"
  support_url: "https://github.com/your-repo/issues"  # New: support/issue tracking URL

# Global settings
settings:
  continue_on_error: true        # Continue installation if individual items fail
  update_packages: true          # Run apt update before installing packages
  cleanup_after_install: true   # Clean package cache after installation
  log_level: "INFO"             # DEBUG, INFO, WARN, ERROR
  max_retries: 3                # Number of retry attempts for failed installations

# Prerequisites (installed first)
prerequisites:
  - curl
  - wget
  - yq

# APT packages
apt_packages:
  - name: package-name
    version: latest              # "latest" or specific version
    description: "Package description"
    command: package-binary      # Optional: command name to verify

# Shell configuration
shell_setup:
  - name: config-name
    description: "Configuration description"
    enabled: true
    script: relative/path/to/script.sh

# Custom software installations
custom_software:
  - name: software-name
    description: "Software description"
    script: software-folder/install.sh
    depends_on: [dependency1, dependency2]  # Optional dependencies
    version_command: command-name            # Optional version check
    version_flag: --version                 # Optional version flag

# Python packages
python_packages:
  - name: package-name
    version: latest
    description: "Package description"
    install_method: pipx        # "pip", "pipx", or "apt"

# PowerShell modules
powershell_modules:
  - name: ModuleName
    version: latest
    description: "Module description"

# Nix packages (requires Nix installation)
nix_packages:
  - flake:
      enabled: true
      type: local               # "local" or "remote"
      path: "./install.flake.nix"  # For local flakes
      url: "github:user/repo"   # For remote flakes
      description: "Flake description"
  - packages:
      enabled: true
      list:
        - name: package-name
          package: "nixpkgs.package-name"
          description: "Package description"

# Post-installation configurations
configurations:
  - name: config-name
    description: "Configuration description"
    enabled: true
    script: |
      # Inline bash script
      echo "Configuration script"
```

## Configuration Sections

### 1. Metadata Section

The metadata section provides information about your configuration:

```yaml
metadata:
  name: "My Development Environment"
  description: "Custom development setup for my team"
  version: "2.1.0"
  target_os: "ubuntu-24.04"
  author: "development-team"
  support_url: "https://github.com/myorg/myrepo/issues"
```

**Fields:**
- `name`: Human-readable environment name
- `description`: Detailed description of the environment purpose
- `version`: Semantic version of your configuration
- `target_os`: Target operating system (currently `ubuntu-24.04`)
- `author`: Configuration author or team name
- `support_url`: Optional URL for support, issues, or documentation

### 2. Settings Section

Global behavior settings:

```yaml
settings:
  continue_on_error: true        # Don't stop on individual failures
  update_packages: true          # Update package lists before installation
  cleanup_after_install: true   # Clean package cache after completion
  log_level: "INFO"             # Logging verbosity
  max_retries: 3                # Retry attempts for network failures
```

**Settings Options:**
- `continue_on_error`: `true` (recommended) | `false` - Whether to continue if individual packages fail
- `update_packages`: `true` | `false` - Whether to run `apt update` before installations
- `cleanup_after_install`: `true` | `false` - Whether to clean package cache after installation
- `log_level`: `"DEBUG"` | `"INFO"` | `"WARN"` | `"ERROR"` - Logging verbosity level
- `max_retries`: Integer - Number of retry attempts for failed network operations

### 3. Prerequisites Section

System packages that must be installed before everything else:

```yaml
prerequisites:
  - curl                    # Required for downloading software
  - wget                    # Alternative download tool
  - yq                      # YAML processor (required by installer)
  - software-properties-common  # For adding PPAs
  - apt-transport-https     # For HTTPS repositories
  - ca-certificates         # SSL certificates
  - gnupg                   # GPG keys for repositories
  - lsb-release             # OS version detection
```

**Best Practices:**
- Keep minimal - only essential system tools
- Include tools needed by custom installation scripts
- Don't include user applications here

### 4. APT Packages Section

Ubuntu packages installed via apt package manager:

```yaml
apt_packages:
  - name: git
    version: latest
    description: "Version control system"
    command: git                    # Optional: command to verify installation

  - name: python3
    version: "3.11*"               # Version pattern matching
    description: "Python programming language"
    
  - name: nodejs
    version: latest
    description: "JavaScript runtime"
    command: node
```

**Package Fields:**
- `name`: Exact apt package name (required)
- `version`: `"latest"` | specific version | version pattern (required)
- `description`: Human-readable description (optional but recommended)
- `command`: Command name to verify installation (optional)

**Version Specifications:**
- `"latest"`: Install latest available version
- `"1.2.3"`: Install specific version
- `"1.2.*"`: Install latest patch version of 1.2.x
- `">=1.2.0"`: Install version 1.2.0 or later

### 5. Shell Setup Section

Shell configuration that runs before custom software installation:

```yaml
shell_setup:
  - name: set-zsh-default
    description: "Set zsh as default shell for all users"
    enabled: true
    script: shell-config/set-zsh-default.sh
    
  - name: configure-oh-my-zsh
    description: "Set up oh-my-zsh framework"
    enabled: false                  # Can be disabled without removing
    script: shell-config/oh-my-zsh-setup.sh
```

**Shell Setup Fields:**
- `name`: Unique configuration name (required)
- `description`: Human-readable description (required)
- `enabled`: `true` | `false` - Whether to run this configuration (required)
- `script`: Path to script relative to software-scripts directory (required)

### 6. Custom Software Section

Software not available via apt, installed using custom scripts:

```yaml
custom_software:
  - name: docker
    description: "Docker container engine"
    script: docker/install.sh
    depends_on: [curl, ca-certificates]
    version_command: docker
    version_flag: --version

  - name: nodejs-lts
    description: "Node.js LTS via NodeSource"
    script: nodejs/install.sh
    version_command: node
    version_flag: --version
```

**Custom Software Fields:**
- `name`: Unique software identifier (required)
- `description`: Human-readable description (required)
- `script`: Path to install script relative to software-scripts directory (required)
- `depends_on`: Array of dependency names (optional)
- `version_command`: Command to check version (optional)
- `version_flag`: Flag to get version info (optional, defaults to `--version`)

**Installation Script Requirements:**
- Must be executable bash script
- Should check if already installed before installing
- Should verify successful installation
- Should use logging functions from utilities
- Should return appropriate exit codes

### 7. Python Packages Section

Python packages installed via pip, pipx, or apt:

```yaml
python_packages:
  - name: pre-commit
    version: latest
    description: "Pre-commit hooks framework"
    install_method: pipx           # Isolated installation

  - name: requests
    version: ">=2.25.0"
    description: "HTTP library"
    install_method: pip            # Global pip installation

  - name: python3-venv
    version: latest
    description: "Virtual environment support"
    install_method: apt            # Install via apt instead of pip
```

**Python Package Fields:**
- `name`: Package name (PyPI name for pip/pipx, apt package name for apt)
- `version`: Version specification following pip conventions
- `description`: Human-readable description
- `install_method`: `"pip"` | `"pipx"` | `"apt"` (defaults to `"pipx"`)

**Installation Methods:**
- `pip`: Global installation via pip (not recommended for applications)
- `pipx`: Isolated application installation (recommended for CLI tools)
- `apt`: Install via apt package manager (for system integration)

### 8. PowerShell Modules Section

PowerShell modules for PowerShell Core:

```yaml
powershell_modules:
  - name: Pester
    version: latest
    description: "PowerShell testing framework"
    
  - name: PSReadLine
    version: "2.2.6"
    description: "Command line editing experience"
```

**PowerShell Module Fields:**
- `name`: Exact PowerShell Gallery module name
- `version`: `"latest"` | specific version
- `description`: Human-readable description

### 9. Nix Packages Section

Packages managed by Nix package manager (requires Nix installation):

```yaml
nix_packages:
  # Local flake installation
  - flake:
      enabled: true
      type: local
      path: "./install.flake.nix"
      description: "Local development tools flake"
      
  # Remote flake installation
  - flake:
      enabled: false
      type: remote
      url: "github:username/repository?dir=nix"
      description: "Remote development tools"
      
  # Individual package installation
  - packages:
      enabled: true
      list:
        - name: hello
          package: "nixpkgs.hello"
          description: "Hello world program"
        - name: ripgrep
          package: "nixpkgs.ripgrep"
          description: "Fast text search tool"
```

**Nix Configuration:**
- Supports both flakes and individual packages
- Flakes can be local files or remote repositories
- Individual packages use nixpkgs package names
- All installations attempt system-wide installation when possible

### 10. Configurations Section

Post-installation configuration scripts:

```yaml
configurations:
  - name: configure-git
    description: "Set up global Git configuration"
    enabled: true
    script: |
      git config --global init.defaultBranch main
      git config --global core.autocrlf input
      git config --global pull.rebase false
      
  - name: configure-docker
    description: "Add user to docker group"
    enabled: true
    script: |
      sudo usermod -aG docker $USER
      echo "Please log out and back in for docker group changes to take effect"
```

**Configuration Fields:**
- `name`: Unique configuration identifier
- `description`: Human-readable description
- `enabled`: Whether to run this configuration
- `script`: Inline bash script (use `|` for multi-line)

## Git SSH Keys Configuration

The SSH keys feature allows you to automatically set up SSH keys for Git repositories by creating symlinks from your Windows user profile to the WSL user profile.

```yaml
git_ssh_keys:
  enabled: true                    # Enable/disable SSH key configuration
  keys:
    - name: "github"              # Unique identifier for this key pair
      private_key: "id_ed25519"   # Private key filename in Windows ~/.ssh/
      public_key: "id_ed25519.pub" # Public key filename in Windows ~/.ssh/
      hosts:
        - name: "github"          # SSH host alias
          hostname: "github.com"  # Actual hostname
          user: "git"             # SSH user
          port: 22                # SSH port
          preferred_authentications: "publickey"
          identities_only: true   # Only use specified identity
          forward_agent: false    # Don't forward SSH agent
          server_alive_interval: 60    # Keep connection alive
          server_alive_count_max: 5    # Max keep-alive attempts
    
    - name: "gitlab"              # Example: second key for GitLab
      private_key: "id_rsa_gitlab"
      public_key: "id_rsa_gitlab.pub"
      hosts:
        - name: "gitlab"
          hostname: "gitlab.com"
          user: "git"
          port: 22
          preferred_authentications: "publickey"
          identities_only: true
          forward_agent: false
          server_alive_interval: 60
          server_alive_count_max: 5
```

**SSH Keys Features:**

- **Automatic Symlinks**: Creates symlinks from Windows `%USERPROFILE%\.ssh\` to WSL `~/.ssh/`
- **Proper Permissions**: Sets 600 for private keys, 644 for public keys
- **SSH Agent Integration**: Automatically configures SSH agent to load keys on startup
- **Host Configuration**: Generates `~/.ssh/config` with per-host settings
- **Multi-Key Support**: Supports multiple SSH key pairs for different services

**Prerequisites:**
- SSH keys must exist in Windows user profile `.ssh` directory
- Keys should be generated using standard tools (ssh-keygen, PuTTYgen, etc.)
- Windows user profile must be accessible from WSL

**Security Considerations:**
- Only creates symlinks, doesn't copy sensitive key material
- Validates key file existence before creating symlinks
- Sets secure file permissions automatically
- Input validation prevents injection attacks

## Example Configurations

### Minimal Developer Setup

```yaml
metadata:
  name: "Minimal Developer Setup"
  description: "Essential tools for basic development"
  version: "1.0.0"

settings:
  continue_on_error: true
  log_level: "INFO"

apt_packages:
  - name: git
    version: latest
    description: "Version control"
  - name: curl
    version: latest
    description: "Data transfer tool"
  - name: jq
    version: latest
    description: "JSON processor"

custom_software:
  - name: nodejs-lts
    description: "Node.js LTS"
    script: nodejs/install.sh

python_packages:
  - name: pre-commit
    version: latest
    description: "Pre-commit hooks"
    install_method: pipx
```

### Data Science Environment

```yaml
metadata:
  name: "Data Science Environment"
  description: "Python-focused data analysis setup"
  version: "1.0.0"

apt_packages:
  - name: python3
    version: latest
  - name: python3-pip
    version: latest
  - name: python3-venv
    version: latest
  - name: python3-dev
    version: latest
  - name: build-essential
    version: latest

python_packages:
  - name: jupyter
    version: latest
    install_method: pipx
  - name: pandas
    version: latest
    install_method: pip
  - name: numpy
    version: latest
    install_method: pip
  - name: matplotlib
    version: latest
    install_method: pip
```

## Configuration Best Practices

### 1. Structure and Organization

- Use descriptive names and descriptions
- Group related packages together
- Order dependencies before dependents
- Keep configurations focused and modular

### 2. Version Management

- Use `"latest"` for most packages to get updates
- Pin critical versions for stability
- Document version constraints reasoning
- Test version updates in non-production first

### 3. Error Handling

- Set `continue_on_error: true` for resilience
- Use appropriate retry counts for network issues
- Include fallback options where possible
- Test failure scenarios

### 4. Performance

- Minimize prerequisites to essential items only
- Use pipx for Python CLI applications
- Group related operations together
- Consider installation order for dependencies

### 5. Maintainability

- Document complex configurations
- Use version control for configuration files
- Test configurations regularly
- Keep alternative configurations for different use cases

## Validation and Testing

### Syntax Validation

The installer validates YAML syntax before execution:

```bash
# Test configuration syntax
./src/install.sh --config my-config.yaml --dry-run
```

### Dependency Checking

Dependencies in `depends_on` arrays are verified:
- Must reference packages in apt_packages or other custom_software
- Circular dependencies are detected and reported
- Missing dependencies cause installation to fail

### Installation Testing

After creating configurations, test them:

```bash
# Test full installation
./src/install.sh --config my-config.yaml

# Test specific sections
./src/install.sh --config my-config.yaml --sections custom_software

# Verify installation
./src/tests/test-installation.sh
```

This configuration reference provides all the information needed to create custom development environments tailored to your specific needs.
