# Installation Guide

This guide provides comprehensive instructions for installing and setting up the WSL Ubuntu DevBox Installer.

## System Requirements

### Windows Requirements
- Windows 10 version 2004 and higher (Build 19041 and higher) or Windows 11
- WSL 2 enabled and configured
- PowerShell 5.1 or PowerShell 7+ 
- Administrator privileges for WSL management operations

### Hardware Requirements
- 8 GB RAM minimum (16 GB recommended)
- 10 GB free disk space minimum (20 GB recommended for full installation)
- x64 processor with virtualization support

### Network Requirements
- Internet connection for downloading packages
- Access to GitHub, Ubuntu repositories, and software vendor sites
- Corporate firewall allowances for package managers (if applicable)

## Pre-Installation Setup

### 1. Enable WSL 2

If WSL is not already installed:

```powershell
# Enable WSL and Virtual Machine Platform features
wsl --install

# Restart your computer after this command
```

If WSL is already installed but you need to enable WSL 2:

```powershell
# Set WSL 2 as default
wsl --set-default-version 2

# Check WSL status
wsl --status
```

### 2. Install Ubuntu 24.04 LTS

```powershell
# Install Ubuntu 24.04 from Microsoft Store or via command
wsl --install -d Ubuntu-24.04

# Or if you need to set it as default after installation
wsl --set-default Ubuntu-24.04
```

### 3. Verify PowerShell Version

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Should be 5.1 or higher
```

## Installation Methods

### Method 1: Quick Installation (Recommended)

For most users, this is the simplest approach:

```powershell
# Clone the repository
git clone https://github.com/andresrocksuk/ubuntu-devbox-installer.git
cd ubuntu-devbox-installer

# Run full installation with automatic user creation
.\install-wsl.ps1 -AutoInstall
```

This will:
- Verify WSL setup
- Copy installation files to temp directory for performance
- Run the complete installation
- Create a default WSL user
- Show installation summary

### Method 2: Clean Installation

If you want to start completely fresh:

```powershell
# Reset WSL and install everything from scratch
.\install-wsl.ps1 -ResetWSL -AutoInstall

# WARNING: This will destroy existing WSL Ubuntu installation
```

### Method 3: Selective Installation

Install only specific components:

```powershell
# Install only prerequisites and basic packages
.\install-wsl.ps1 -AutoInstall -Sections "prerequisites","apt_packages"

# Install only development tools
.\install-wsl.ps1 -AutoInstall -Sections "custom_software"

# Available sections:
# - prerequisites      (essential system packages)
# - apt_packages      (Ubuntu repository packages)  
# - shell_setup       (zsh and oh-my-zsh)
# - custom_software   (Docker, Node.js, Go, etc.)
# - python_packages   (pip/pipx packages)
# - powershell_modules (Windows PowerShell modules)
# - nix_packages      (Nix flake packages)
# - configurations    (post-install configurations)
```

### Method 4: Remote Configuration

Use configurations directly from URLs:

```powershell
# Use remote configuration from GitHub
.\install-wsl.ps1 -AutoInstall -Config "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/refs/heads/main/src/install.yaml"

# Use your own remote configuration
.\install-wsl.ps1 -AutoInstall -Config "https://raw.githubusercontent.com/yourusername/your-repo/main/my-config.yaml"

# Combine with sections for selective remote installation
.\install-wsl.ps1 -AutoInstall -Config "https://example.com/config.yaml" -Sections "prerequisites","custom_software"
```

### Method 5: Using Example Configurations

```powershell
# Install only core packages
.\install-wsl.ps1 -AutoInstall -Sections "prerequisites","apt_packages"

# Install only development tools
.\install-wsl.ps1 -AutoInstall -Sections "custom_software","python_packages"
```

Available configuration sections:
- `prerequisites` - Essential system packages
- `apt_packages` - Ubuntu packages via apt
- `shell_setup` - Shell configuration (zsh setup)
- `custom_software` - Custom installation scripts
- `python_packages` - Python packages via pip/pipx
- `powershell_modules` - PowerShell modules
- `nix_packages` - Nix package manager packages
- `configurations` - Post-install configurations

### Method 4: Custom Configuration File

Use a custom configuration file or remote configuration:

```powershell
# Use a local custom configuration file
.\install-wsl.ps1 -AutoInstall -Config "path\to\custom-config.yaml"

# Use a remote configuration file
.\install-wsl.ps1 -AutoInstall -Config "https://raw.githubusercontent.com/username/repo/main/config.yaml"

# Combine custom config with specific sections
.\install-wsl.ps1 -AutoInstall -Config "custom-config.yaml" -Sections "prerequisites","apt_packages"
```

### Method 5: Unattended Installation

For automation or CI/CD scenarios:

```powershell
# Set password via environment variable
$env:WSL_DEFAULT_PASSWORD = "YourSecurePassword123!"

# Run completely unattended
.\install-wsl.ps1 -AutoInstall -Force

# This will use current Windows username and environment password
```

## Installation Process

### What Happens During Installation

1. **Pre-flight Checks**
   - Verifies WSL status and distribution
   - Checks PowerShell version
   - Validates administrator privileges

2. **File Preparation**
   - Copies installation files to WSL temp directory
   - Sets proper permissions on scripts
   - Initializes logging system

3. **Installation Phases**
   - Prerequisites installation
   - APT package installation
   - Shell setup (zsh configuration)
   - Custom software installation
   - Python package installation
   - PowerShell module installation
   - Nix package installation (if enabled)
   - Final configurations

4. **User Setup** (if -AutoInstall used)
   - Creates WSL user account
   - Configures default user
   - Sets up user environment

5. **Verification & Cleanup**
   - Tests installed software
   - Generates installation report
   - Copies logs to Windows accessible location
   - Cleans up temporary files

### Monitoring Installation Progress

The installer provides real-time feedback:

- **Colored output**: Success (green), warnings (yellow), errors (red)
- **Progress indicators**: Shows current phase and item being installed
- **Log streaming**: Real-time log output during installation
- **Installation summary**: Final report of successes and failures

### Log Files

All installation activities are logged with a unique run ID:

```
src/utils/logs/
├── wsl-installation-YYYYMMDD_HHMMSS.log    # Main installation log
├── installation-report-YYYYMMDD_HHMMSS.txt # Software versions
└── test-results-YYYYMMDD_HHMMSS.txt        # Test results (if run)
```

## Post-Installation

### Verification

Test your installation:

```powershell
# From Windows - test all software
.\test-installation-wsl.ps1

# From WSL - run specific tests
wsl --distribution Ubuntu-24.04
cd /path/to/installer
./src/tests/test-installation.sh --report
```

### First Steps in Your New Environment

1. **Open WSL Terminal**
   ```powershell
   wsl --distribution Ubuntu-24.04
   ```

2. **Verify Core Tools**
   ```bash
   # Check essential tools
   git --version
   python3 --version
   node --version
   go version
   
   # Check Docker
   docker --version
   sudo systemctl start docker  # If not auto-started
   ```

3. **Configure Git** (if not done automatically)
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

4. **Explore Installed Tools**
   ```bash
   # Modern shell features
   zoxide --help
   fzf --help
   bat --help
   
   # Development tools
   kubectl version --client
   helm version
   terraform --version
   ```

## Customization After Installation

### Adding More Software

1. **Via APT** (temporary, not persistent across resets)
   ```bash
   sudo apt install <package-name>
   ```

2. **Via Configuration** (persistent, recommended)
   
   Edit `src/install.yaml` and add to the appropriate section:
   ```yaml
   apt_packages:
     - name: new-package
       version: latest
       description: "Description of new package"
   ```

3. **Custom Installation Script**
   
   Create `src/software-scripts/my-tool/install.sh` and add to config:
   ```yaml
   custom_software:
     - name: my-tool
       description: "My custom tool"
       script: my-tool/install.sh
   ```

### Using Alternative Configurations

```bash
# Use minimal setup for lightweight environments
./src/install.sh --config examples/minimal-dev.yaml

# Use data science setup
./src/install.sh --config examples/data-science.yaml

# Create your own configuration
cp src/install.yaml my-custom-config.yaml
# Edit my-custom-config.yaml
./src/install.sh --config my-custom-config.yaml
```

## Troubleshooting Installation Issues

### Common Installation Problems

1. **WSL Not Responding**
   ```powershell
   # Restart WSL
   wsl --terminate Ubuntu-24.04
   wsl --distribution Ubuntu-24.04
   ```

2. **Permission Denied Errors**
   ```bash
   # Fix common permission issues
   sudo chown -R $USER:$USER ~/.local
   sudo chown -R $USER:$USER ~/.cache
   ```

3. **Package Installation Failures**
   ```bash
   # Update package lists and try again
   sudo apt update
   sudo apt upgrade
   ./src/install.sh --force
   ```

4. **Network Issues**
   ```bash
   # Test connectivity
   curl -I https://github.com
   
   # Configure proxy if needed (corporate networks)
   export http_proxy=http://proxy:port
   export https_proxy=http://proxy:port
   ```

### Recovery Procedures

If installation fails:

1. **Partial Recovery** - Re-run the installer (it's idempotent)
   ```powershell
   .\install-wsl.ps1 -AutoInstall
   ```

2. **Force Reinstall** - Force reinstall everything
   ```bash
   ./src/install.sh --force
   ```

3. **Complete Reset** - Start completely fresh
   ```powershell
   .\install-wsl.ps1 -ResetWSL -AutoInstall
   ```

### Getting Help

If you encounter issues:

1. **Check logs** - Review the installation log for specific errors
2. **Enable debug mode** - Run with `--log-level DEBUG`
3. **Test specific components** - Use selective testing to isolate issues
4. **Consult troubleshooting guide** - See [troubleshooting.md](troubleshooting.md)
5. **Report issues** - Include logs and system information

## Advanced Installation Options

### Corporate Environment Setup

For corporate networks with proxy requirements:

```bash
# Set proxy before installation
export http_proxy=http://proxy.company.com:8080
export https_proxy=http://proxy.company.com:8080
export no_proxy=localhost,127.0.0.1,.company.com

# Run installation
./src/install.sh
```

### CI/CD Integration

For automated deployment:

```yaml
# Example GitHub Actions step
- name: Setup WSL Development Environment
  run: |
    $env:WSL_DEFAULT_PASSWORD = "${{ secrets.WSL_PASSWORD }}"
    .\install-wsl.ps1 -AutoInstall -Force -Config "prerequisites","apt_packages","custom_software"
```

### Performance Optimization

For faster installations:

```powershell
# Use direct mode to avoid temp directory copying (slower but uses less disk)
.\install-wsl.ps1 -AutoInstall -RunDirect

# Use selective installation for only needed components
.\install-wsl.ps1 -AutoInstall -Config "prerequisites","apt_packages"
```

This completes the installation guide. Your WSL Ubuntu development environment should now be ready for productive development work!
