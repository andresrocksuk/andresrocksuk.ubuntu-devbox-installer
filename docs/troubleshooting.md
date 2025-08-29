# Troubleshooting Guide

This guide covers common issues and their solutions for the WSL Ubuntu DevBox Installer system.

## Installation Issues

### WSL Not Available or Not Working

**Problem:** WSL commands fail or are not recognized.

```powershell
wsl : The term 'wsl' is not recognized as the name of a cmdlet...
```

**Solution:**
1. Enable WSL feature:
   ```powershell
   # Run as Administrator
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
   Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
   
   # Restart computer
   Restart-Computer
   ```

2. Install WSL 2:
   ```powershell
   wsl --install
   wsl --set-default-version 2
   ```

### Permission Denied Errors

**Problem:** Installation fails with permission errors.

```bash
chmod: changing permissions of '/usr/local/bin/tool': Operation not permitted
```

**Solutions:**
1. **For system directories:**
   ```bash
   # Use sudo for system locations
   sudo chmod +x /usr/local/bin/tool
   sudo chown root:root /usr/local/bin/tool
   ```

2. **For user directories:**
   ```bash
   # Fix user directory permissions
   sudo chown -R $USER:$USER ~/.local
   sudo chown -R $USER:$USER ~/.cache
   chmod 755 ~/.local/bin
   ```

3. **For script execution:**
   ```bash
   # Make script executable
   chmod +x src/software-scripts/*/install.sh
   ```

### Network and Download Issues

**Problem:** Downloads fail or time out.

```bash
curl: (6) Could not resolve host: github.com
wget: unable to resolve host address 'releases.example.com'
```

**Solutions:**
1. **Check connectivity:**
   ```bash
   # Test basic connectivity
   ping google.com
   curl -I https://github.com
   ```

2. **Configure proxy (corporate networks):**
   ```bash
   # Set proxy environment variables
   export http_proxy=http://proxy.company.com:8080
   export https_proxy=http://proxy.company.com:8080
   export no_proxy=localhost,127.0.0.1,.company.com
   
   # Configure Git proxy
   git config --global http.proxy http://proxy.company.com:8080
   ```

3. **DNS issues:**
   ```bash
   # Use alternative DNS servers
   echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf
   echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf
   ```

### Package Installation Failures

**Problem:** APT packages fail to install.

```bash
E: Unable to locate package some-package
E: Package 'package-name' has no installation candidate
```

**Solutions:**
1. **Update package lists:**
   ```bash
   sudo apt update
   sudo apt upgrade
   ```

2. **Enable universe repository:**
   ```bash
   sudo add-apt-repository universe
   sudo apt update
   ```

3. **Check package name:**
   ```bash
   # Search for correct package name
   apt search package-name
   apt-cache search package-name
   ```

4. **Add required repositories:**
   ```bash
   # Example: Add Node.js repository
   curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
   sudo apt update
   ```

### User Creation Issues

**Problem:** WSL user creation fails or prompts for invalid username.

```
Invalid username. Username must:
- Not be empty
- Only contain letters, numbers, underscores, and hyphens
- Not start with a number or hyphen
- Be 32 characters or less
```

**Solutions:**
1. **Use valid username format:**
   - Only lowercase letters, numbers, underscores, hyphens
   - Start with a letter
   - Maximum 32 characters
   - No spaces or special characters

2. **Set username via environment variable:**
   ```powershell
   $env:WSL_DEFAULT_USERNAME = "validusername"
   .\install-wsl.ps1 -AutoInstall -Force
   ```

3. **Manual user creation:**
   ```bash
   # Create user manually in WSL
   sudo useradd -m -s /bin/bash username
   sudo passwd username
   sudo usermod -aG sudo username
   ```

## Runtime Issues

### Command Not Found After Installation

**Problem:** Installed software is not available in PATH.

```bash
command-name: command not found
```

**Solutions:**
1. **Reload shell configuration:**
   ```bash
   # Reload current shell
   source ~/.bashrc
   source ~/.zshrc
   
   # Or restart shell
   exec bash
   exec zsh
   ```

2. **Check installation location:**
   ```bash
   # Find installed binary
   find /usr -name "command-name" 2>/dev/null
   find /opt -name "command-name" 2>/dev/null
   ls -la /usr/local/bin/command-name
   ```

3. **Update PATH:**
   ```bash
   # Add to PATH temporarily
   export PATH="/usr/local/bin:$PATH"
   
   # Add to shell configuration permanently
   echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
   ```

### Docker Issues

**Problem:** Docker commands fail with permission errors.

```bash
Got permission denied while trying to connect to the Docker daemon socket
```

**Solutions:**
1. **Add user to docker group:**
   ```bash
   sudo usermod -aG docker $USER
   
   # Log out and back in, or restart WSL
   wsl --terminate Ubuntu-24.04
   wsl --distribution Ubuntu-24.04
   ```

2. **Start Docker service:**
   ```bash
   # Check Docker service status
   sudo systemctl status docker
   
   # Start Docker service
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

3. **WSL-specific Docker setup:**
   ```bash
   # For WSL, you might need to start Docker manually
   sudo service docker start
   
   # Add to shell startup
   echo 'sudo service docker start' >> ~/.bashrc
   ```

### Python and pip Issues

**Problem:** Python packages fail to install or aren't found.

```bash
error: externally-managed-environment
pip: command not found
```

**Solutions:**
1. **Use pipx for applications:**
   ```bash
   # Install applications with pipx
   pipx install package-name
   
   # Install libraries with pip in virtual environment
   python3 -m venv myenv
   source myenv/bin/activate
   pip install package-name
   ```

2. **Fix pip installation:**
   ```bash
   # Reinstall pip
   sudo apt remove python3-pip
   sudo apt install python3-pip
   
   # Or use get-pip.py
   curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
   python3 get-pip.py --user
   ```

3. **PEP 668 compliance:**
   ```bash
   # Use --break-system-packages flag (not recommended)
   pip install --break-system-packages package-name
   
   # Better: use virtual environments
   python3 -m venv ~/.local/share/venvs/myenv
   source ~/.local/share/venvs/myenv/bin/activate
   pip install package-name
   ```

## Configuration Issues

### PowerShell Parameter Validation Errors

**Problem:** PowerShell parameter validation fails before execution.

```powershell
install-wsl.ps1: Cannot validate argument on parameter 'Config'. Configuration file does not exist: nonexistent.yaml
```

**Solutions:**
1. **File path issues:**
   ```powershell
   # Wrong: relative path without checking existence
   .\install-wsl.ps1 -Config "config.yaml"
   
   # Right: use full path or verify file exists
   .\install-wsl.ps1 -Config "C:\full\path\to\config.yaml"
   .\install-wsl.ps1 -Config "src\install.yaml"  # Project's default config
   ```

2. **Remote URL validation:**
   ```powershell
   # Wrong: non-HTTPS URL
   .\install-wsl.ps1 -Config "http://example.com/config.yaml"
   
   # Right: HTTPS URL required for security
   .\install-wsl.ps1 -Config "https://example.com/config.yaml"
   ```

3. **Built-in configuration names:**
   ```powershell
   # Wrong: invalid built-in name
   .\install-wsl.ps1 -Config "invalid-config"
   
   # Right: use valid built-in configurations
   .\install-wsl.ps1 -Config "minimal-dev"
   .\install-wsl.ps1 -Config "data-science"
   ```

### YAML Syntax Errors

**Problem:** Configuration file has syntax errors.

```bash
[ERROR] Invalid YAML syntax in configuration file
```

**Solutions:**
1. **Validate YAML syntax:**
   ```bash
   # Check syntax with yq
   yq eval '.' src/install.yaml
   
   # Use online YAML validator
   # Copy content to yamllint.com
   ```

2. **Common YAML issues:**
   ```yaml
   # Wrong: inconsistent indentation
   apt_packages:
     - name: git
   version: latest
   
   # Right: consistent indentation
   apt_packages:
     - name: git
       version: latest
   ```

3. **Fix special characters:**
   ```yaml
   # Wrong: unquoted special characters
   description: Package with : special chars
   
   # Right: quoted strings with special characters
   description: "Package with : special chars"
   ```

### Section Configuration Issues

**Problem:** Invalid configuration section specified.

```bash
Invalid section specified: invalid_section
Valid sections are: prerequisites apt_packages shell_setup custom_software...
```

**Solution:**
Use only valid section names:
```powershell
# Valid sections
.\install-wsl.ps1 -AutoInstall -Config "prerequisites","apt_packages","custom_software"

# Available sections:
# - prerequisites
# - apt_packages
# - shell_setup
# - custom_software
# - python_packages
# - powershell_modules
# - nix_packages
# - configurations
```

## Logging and Debugging

### Enable Debug Mode

For detailed troubleshooting information:

```bash
# Enable debug logging
./src/install.sh --log-level DEBUG

# From PowerShell
.\install-wsl.ps1 -AutoInstall # (debug info included in logs)
```

### Understanding Log Files

Each installation run creates logs with the same run ID:

```
src/utils/logs/
├── wsl-installation-20250827_120000.log    # Main installation log
├── installation-report-20250827_120000.txt # Version and system info
└── test-results-20250827_120000.txt        # Test results (if run)
```

**Reading log patterns:**
```bash
# Success indicators
grep "SUCCESS" logs/wsl-installation-*.log

# Error indicators
grep "ERROR" logs/wsl-installation-*.log

# Warning indicators
grep "WARN" logs/wsl-installation-*.log

# Installation summary
tail -50 logs/wsl-installation-*.log
```

### Common Log Errors

**Lock file errors:**
```bash
E: Could not get lock /var/lib/dpkg/lock-frontend
```
*Solution: Wait for other package operations to complete, or reboot WSL*

**Network timeout errors:**
```bash
curl: (28) Operation timed out after 30000 milliseconds
```
*Solution: Check network connectivity, configure proxy if needed*

**Permission errors:**
```bash
mv: cannot move '/tmp/tool' to '/usr/local/bin/tool': Permission denied
```
*Solution: Ensure script uses sudo for system locations*

## Recovery Procedures

### Partial Installation Recovery

If installation fails partway through:

```bash
# Method 1: Re-run installation (idempotent)
./src/install.sh

# Method 2: Force reinstall specific items
./src/install.sh --force

# Method 3: Install specific sections only
./src/install.sh --sections custom_software,python_packages
```

### Complete Environment Reset

From Windows PowerShell:

```powershell
# Complete WSL reset and reinstall
.\install-wsl.ps1 -ResetWSL -AutoInstall

# WARNING: This destroys existing WSL installation
```

### Manual Cleanup

Remove incomplete installations:

```bash
# Clean package cache
sudo apt clean
sudo apt autoremove

# Remove incomplete custom software
sudo rm -f /usr/local/bin/failed-tool

# Clear temporary directories
sudo rm -rf /tmp/*
rm -rf ~/.cache/*

# Reset user directories
rm -rf ~/.local/share/pipx
rm -rf ~/.local/bin/*
```

## Testing and Verification

### Run Installation Tests

```bash
# Basic verification
./src/tests/test-installation.sh

# Detailed testing with report
./src/tests/test-installation.sh --report

# Test specific software
./src/tests/test-installation.sh --software "git,python3,docker"
```

### Manual Verification

Test individual tools:

```bash
# Check command availability
which git python3 node go docker

# Check versions
git --version
python3 --version
node --version
go version
docker --version

# Test functionality
git status
python3 -c "print('Python works')"
node -e "console.log('Node works')"
echo '{"test": true}' | jq .
```

### Performance Issues

**Slow installation:**
- Use `--run-direct` to avoid temp directory copying
- Check available disk space: `df -h`
- Monitor network speed during downloads

**High memory usage:**
- Close other applications during installation
- Check memory usage: `free -h`
- Consider installing in smaller sections

## Known Issues and Workarounds

### Function Name Conflicts

**Issue:** Installation scripts conflict with shell built-ins.

**Workaround:** This has been fixed in the current version by renaming conflicting functions.

### PowerShell Execution Policy

**Issue:** PowerShell scripts blocked by execution policy.

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### WSL Network Issues

**Issue:** WSL can't connect to internet after Windows hibernation.

**Workaround:**
```powershell
# Restart WSL networking
wsl --shutdown
# Wait 10 seconds
wsl --distribution Ubuntu-24.04
```

### Nix Package Manager Issues

**Issue:** Nix installation fails or packages aren't available.

**Solutions:**
1. **Install Nix manually first:**
   ```bash
   curl -L https://nixos.org/nix/install | sh
   source ~/.nix-profile/etc/profile.d/nix.sh
   ```

2. **Enable experimental features:**
   ```bash
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```

## Getting More Help

### System Information Collection

When reporting issues, collect this information:

```bash
# System info
uname -a
lsb_release -a
wsl --version

# Disk space
df -h

# Memory
free -h

# Network
ip addr show
cat /etc/resolv.conf

# Installed software versions
./src/tests/test-installation.sh --report
```

### Reporting Issues

Include in your issue report:
1. Complete error messages from logs
2. System information (above)
3. Steps to reproduce the problem
4. Configuration file used (if custom)
5. Output of test script

### Emergency Recovery

If WSL becomes completely unusable:

```powershell
# From Windows Command Prompt or PowerShell
wsl --terminate Ubuntu-24.04
wsl --unregister Ubuntu-24.04

# Reinstall Ubuntu 24.04 from Microsoft Store
# Then run the installation system again
.\install-wsl.ps1 -AutoInstall
```

### Community Support

- Check GitHub Issues for similar problems
- Search documentation for related topics
- Use GitHub Discussions for questions
- Provide detailed error information when asking for help

---

**Remember:** The installation system is designed to be idempotent and resilient. Most issues can be resolved by simply running the installation again after addressing the underlying cause.
