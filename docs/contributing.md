# Contributing Guide

Welcome to the WSL Ubuntu DevBox Installer project! This guide will help you contribute effectively to the project.

## Getting Started

### Development Environment Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/andresrocksuk/ubuntu-devbox-installer.git
   cd ubuntu-devbox-installer
   ```

2. **Set up development environment:**
   ```powershell
   # Test the current installation system
   .\install-wsl.ps1 -AutoInstall
   
   # Verify everything works
   .\test-installation-wsl.ps1
   ```

3. **Understand the project structure:**
   ```
   ubuntu-devbox-installer/
   ├── src/
   │   ├── install.sh              # Main installation engine
   │   ├── install.yaml            # Default configuration
   │   ├── shell-setup/            # Shell configuration scripts  
   │   ├── custom-software/        # Individual software installers
   │   ├── configurations/         # Configuration scripts
   │   ├── utils/                  # Core utilities
   │   └── tests/                  # Testing framework
   ├── examples/                   # Example configurations
   ├── docs/                       # Documentation
   └── .github/                    # GitHub workflows and templates
   ```

## Types of Contributions

### 1. Adding New Software

The most common contribution is adding support for new software packages.

#### Step-by-Step Process

1. **Create the installation script:**

   ```bash
   mkdir src/custom-software/your-software
   touch src/custom-software/your-software/install.sh
   chmod +x src/custom-software/your-software/install.sh
   ```

2. **Follow the standard template:**
   ```bash
   #!/bin/bash
   
   # your-software installation script
   # Brief description of what this software does
   
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
   fi
   
   install_your_software() {
       log_info "Installing Your Software..."
       
       # Check if already installed
       if command -v your-software >/dev/null 2>&1; then
           local current_version=$(your-software --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")
           log_info "Your Software is already installed (version: $current_version)"
           return 0
       fi
       
       # Installation logic here
       # Examples:
       # - Download from GitHub releases
       # - Install via package manager
       # - Compile from source
       
       # Verify installation
       if command -v your-software >/dev/null 2>&1; then
           local installed_version=$(your-software --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")
           log_success "Your Software installed successfully (version: $installed_version)"
           
           # Test the installation
           log_info "Testing Your Software installation..."
           your-software --help >/dev/null && log_success "Your Software test successful"
           
           return 0
       else
           log_error "Your Software installation verification failed"
           return 1
       fi
   }
   
   # Run installation
   install_your_software
   ```

3. **Add to configuration:**
   
   Edit `src/install.yaml` and add your software to the `custom_software` section:
   ```yaml
   custom_software:
     - name: your-software
       description: "Brief description of your software"
       script: your-software/install.sh
       depends_on: [curl]  # Optional dependencies
       version_command: your-software  # Optional
       version_flag: --version        # Optional
   ```

4. **Test your installation:**
   ```powershell
   # Test only your software
   .\install-wsl.ps1 -AutoInstall -Config custom_software
   
   # Test the full installation
   .\install-wsl.ps1 -ResetWSL -AutoInstall
   
   # Run verification tests
   .\test-installation-wsl.ps1
   ```

#### Installation Script Best Practices

**Required Elements:**
- Check if already installed before installing
- Use logging functions for consistent output
- Verify installation after completion
- Return appropriate exit codes (0 = success, 1 = failure)
- Handle both curl and wget for downloads

**Recommended Patterns:**
- Get latest version from GitHub releases API
- Download to temporary files and clean up
- Use sudo only when necessary
- Test the installed software works
- Extract version numbers for logging

**Example GitHub Release Download:**
```bash
# Get latest release info from GitHub API
local api_url="https://api.github.com/repos/owner/repo/releases/latest"
local release_info
if command -v curl >/dev/null 2>&1; then
    release_info=$(curl -s "$api_url")
elif command -v wget >/dev/null 2>&1; then
    release_info=$(wget -qO- "$api_url")
fi

# Extract download URL
local download_url=$(echo "$release_info" | grep -o '"browser_download_url": "[^"]*linux_amd64[^"]*"' | cut -d'"' -f4 | head -n1)

# Download and install
local temp_file="/tmp/your-software"
curl -L "$download_url" -o "$temp_file"
sudo install "$temp_file" /usr/local/bin/your-software
rm "$temp_file"
```

### 2. Improving Existing Software Scripts

You can improve existing installation scripts by:

- Adding better error handling
- Supporting more installation methods
- Improving version detection
- Adding dependency checks
- Enhancing verification tests

### 3. Creating Example Configurations

Create specialized configurations for different use cases:

1. **Create configuration file:**
   ```bash
   cp examples/minimal-dev.yaml examples/your-use-case.yaml
   ```

2. **Customize for your use case:**
   ```yaml
   metadata:
     name: "Your Use Case Environment"
     description: "Specialized setup for [specific purpose]"
     version: "1.0.0"
   
   # Customize packages for your use case
   apt_packages:
     # ... relevant packages
   
   custom_software:
     # ... relevant software
   ```

3. **Test and document:**
   ```bash
   ./src/install.sh --config examples/your-use-case.yaml --dry-run
   ./src/install.sh --config examples/your-use-case.yaml
   ```

### 4. Documentation Improvements

- Update README for new features
- Improve troubleshooting guides
- Add usage examples
- Document configuration options
- Write tutorials for common scenarios

### 5. Testing and Quality Assurance

- Add test cases for new software
- Improve error handling
- Test on different Ubuntu versions
- Performance improvements
- Security enhancements

## Development Guidelines

### Code Style

#### Bash Scripts
- Use `set -e` for error handling
- Use consistent indentation (2 spaces)
- Quote variables to prevent word splitting
- Use descriptive function and variable names
- Add comments for complex logic

```bash
#!/bin/bash
set -e

# Good examples
local package_name="$1"
if [ -n "$package_name" ]; then
    log_info "Installing $package_name..."
fi

# Use arrays for multiple items
local dependencies=("curl" "wget" "jq")
for dep in "${dependencies[@]}"; do
    check_dependency "$dep"
done
```

#### YAML Configuration
- Use consistent indentation (2 spaces)
- Add descriptions for all packages
- Group related packages together
- Use semantic versioning for metadata

```yaml
# Good example
apt_packages:
  - name: git
    version: latest
    description: "Distributed version control system"
    
  - name: curl
    version: latest
    description: "Command line tool for transferring data with URL syntax"
```

#### PowerShell Scripts
- Use approved verbs for functions
- Follow PowerShell naming conventions
- Add parameter validation
- Include help documentation

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("INFO", "DEBUG", "WARN", "ERROR")]
    [string]$LogLevel = "INFO"
)
```

### Testing Requirements

#### Before Submitting
1. **Syntax validation:**
   ```bash
   # Test YAML syntax
   ./src/install.sh --config your-config.yaml --dry-run
   
   # Test bash script syntax
   bash -n your-script.sh
   ```

2. **Functional testing:**
   ```powershell
   # Fresh installation test
   .\install-wsl.ps1 -ResetWSL -AutoInstall
   
   # Verify all software works
   .\test-installation-wsl.ps1
   ```

3. **Idempotency testing:**
   ```bash
   # Run installation twice to ensure idempotency
   ./src/install.sh
   ./src/install.sh
   ```

#### Test Cases to Consider
- Fresh installation on clean WSL
- Re-running installation (idempotency)
- Partial installation failures
- Network connectivity issues
- Permission problems
- Different Ubuntu versions

### Git Workflow

#### Branching Strategy
- `main` branch for stable releases
- Feature branches for new development
- Bug fix branches for issues

#### Commit Messages
Use conventional commit format:
```
type(scope): description

feat(software): add support for new-tool installation
fix(docker): resolve permission issues in docker installation
docs(readme): update installation instructions
test(nodejs): add version verification for nodejs
```

#### Pull Request Process
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes and test thoroughly
4. Commit with descriptive messages
5. Push to your fork: `git push origin feature/your-feature`
6. Create a pull request with:
   - Clear description of changes
   - Testing performed
   - Any breaking changes
   - Screenshots if applicable

## Submitting Contributions

### Pull Request Template

When submitting a pull request, include:

```markdown
## Description
Brief description of what this PR accomplishes.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing Performed
- [ ] Fresh WSL installation test
- [ ] Idempotency test (ran installation twice)
- [ ] Specific software verification
- [ ] Test suite passed

## Software Added/Modified
List any new software or changes to existing installations.

## Dependencies
List any new dependencies added.

## Breaking Changes
Describe any breaking changes and migration path.

## Screenshots
Include screenshots of successful installation/testing if applicable.
```

### Review Process

1. **Automated checks:** GitHub Actions will run automated tests
2. **Code review:** Maintainers will review code quality and design
3. **Testing verification:** Reviewers may test your changes
4. **Documentation check:** Ensure documentation is updated
5. **Approval and merge:** Once approved, changes will be merged

## Common Issues and Solutions

### Installation Script Issues

**Issue: Script fails silently**
```bash
# Solution: Add proper error handling
set -e  # Exit on any error
# Check return codes explicitly
if ! some_command; then
    log_error "Command failed"
    return 1
fi
```

**Issue: Version detection fails**
```bash
# Solution: Handle different version output formats
local version_output=$(command --version 2>/dev/null || command -v 2>/dev/null || echo "unknown")
local version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")
```

**Issue: Dependencies not satisfied**
```yaml
# Solution: Add proper dependencies to configuration
custom_software:
  - name: your-tool
    script: your-tool/install.sh
    depends_on: [curl, ca-certificates]  # Add required dependencies
```

### Testing Issues

**Issue: Test failures in CI**
- Ensure scripts work in non-interactive mode
- Handle missing interactive shells
- Don't rely on user-specific configurations

**Issue: Idempotency failures**
- Always check if software is already installed
- Use version checking to avoid unnecessary reinstalls
- Clean up temporary files properly

## Getting Help

If you need help contributing:

1. **Check existing issues:** Look for similar problems or questions
2. **Create a discussion:** Use GitHub Discussions for questions
3. **Join the community:** Participate in issue discussions
4. **Read the documentation:** Check all docs files
5. **Ask specific questions:** Provide context and error messages

## Recognition

Contributors are recognized in:
- Git commit history
- Release notes for significant contributions
- Contributors section in README
- Special recognition for major features

Thank you for contributing to the WSL Ubuntu DevBox Installer project!
