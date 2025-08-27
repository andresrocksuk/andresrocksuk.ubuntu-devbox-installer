# Documentation

Welcome to the WSL Ubuntu DevBox Installer documentation. This directory contains comprehensive guides for installing, configuring, and extending the system.

## 📚 Documentation Structure

### Getting Started
- **[Installation Guide](installation-guide.md)** - Complete setup instructions from prerequisites to post-installation
- **[README](../readme.md)** - Project overview, quick start, and basic usage

### Configuration and Usage
- **[Configuration Reference](configuration-reference.md)** - Complete YAML schema and configuration options
- **[API Reference](api-reference.md)** - Utility functions, scripting APIs, and technical reference

### Development and Contribution
- **[Contributing Guide](contributing.md)** - How to add software, improve scripts, and contribute to the project
- **[Troubleshooting](troubleshooting.md)** - Common issues, solutions, and debugging techniques

## 🚀 Quick Navigation

### For New Users
1. Start with the [Installation Guide](installation-guide.md) for step-by-step setup
2. Check the main [README](../readme.md) for quick start examples
3. Reference [Troubleshooting](troubleshooting.md) if you encounter issues

### For Configuration
1. Review [Configuration Reference](configuration-reference.md) for YAML options
2. See `examples/` directory for pre-built configurations
3. Use [API Reference](api-reference.md) for advanced customization

### For Developers
1. Read the [Contributing Guide](contributing.md) for development setup
2. Use [API Reference](api-reference.md) for scripting and utilities
3. Check `.github/copilot-instructions.md` for AI assistant guidance

## 📖 Key Topics

### Installation Options
- **Standard Installation**: Full development environment setup
- **Selective Installation**: Choose specific software packages
- **Custom Configurations**: Create environment-specific setups
- **Unattended Installation**: Automated deployment scenarios

### Software Management
- **15+ Pre-built Scripts**: Docker, Node.js, Python, Go, Kubernetes tools
- **Multi-Package Manager**: apt, pip/pipx, PowerShell, Nix support
- **Version Management**: Latest version fetching with fallbacks
- **Dependency Handling**: Automatic prerequisite installation

### Advanced Features
- **Idempotent Operations**: Safe to run multiple times
- **Comprehensive Logging**: Single-run ID correlation across all logs
- **Error Recovery**: Continue on individual failures with detailed reporting
- **Windows Integration**: PowerShell-based WSL management and reset

## 🔧 Common Use Cases

### Development Team Setup
```powershell
# Standard team development environment
.\install-wsl.ps1 -AutoInstall
```

### Data Science Environment
```powershell
# Python-focused setup with analysis tools
.\install-wsl.ps1 -AutoInstall -Config @("examples/data-science.yaml")
```

### Minimal Setup
```powershell
# Lightweight environment for basic development
.\install-wsl.ps1 -AutoInstall -Config @("examples/minimal-dev.yaml")
```

### Custom Corporate Environment
```yaml
# Create custom configuration
metadata:
  name: "Corporate Development Environment"
  description: "Company-specific tools and configurations"

# Add company-specific packages and tools
apt_packages:
  - name: company-vpn-client
    version: latest

custom_software:
  - name: company-tools
    script: company-tools/install.sh
```

## 🛠️ System Architecture

The installer follows a modular architecture:

```
Installation Flow:
├── PowerShell Orchestrator (install-wsl.ps1)
├── Bash Installation Engine (src/install.sh)
├── YAML Configuration Parser
├── Modular Software Scripts (src/software-scripts/)
├── Utility Libraries (src/utils/)
└── Testing Framework (src/tests/)
```

### Key Components

- **Declarative Configuration**: YAML-based environment specification
- **Modular Scripts**: Individual installation scripts for each software
- **Logging System**: Comprehensive logging with run ID correlation
- **Testing Framework**: Built-in verification and reporting
- **Windows Integration**: PowerShell WSL management utilities

## 📊 Logging and Monitoring

All operations are logged with unique run IDs for easy correlation:

```
Logs Structure:
src/utils/logs/
├── wsl-installation-{RUNID}.log    # Main installation log
├── installation-report-{RUNID}.txt # Version and system report
└── test-results-{RUNID}.txt        # Test verification results
```

### Log Analysis
- **Real-time monitoring**: Live log streaming during installation
- **Error correlation**: All logs from single run share same timestamp
- **Detailed reporting**: Version info, system state, and test results
- **Troubleshooting**: Debug mode with verbose output

## 🧪 Testing and Validation

Comprehensive testing ensures reliability:

### Installation Testing
```powershell
# Full system verification
.\test-installation-wsl.ps1

# Specific software testing
./src/tests/test-installation.sh --software "docker,nodejs,python3"

# Detailed reporting
./src/tests/test-installation.sh --report
```

### Validation Features
- **Software presence verification**: Confirms all tools are installed
- **Version reporting**: Documents installed software versions
- **Functionality testing**: Basic operation verification
- **Performance monitoring**: Installation time and resource usage

## 🔄 Maintenance and Updates

### Keeping Current
- **Regular updates**: Re-run installation to get latest versions
- **Configuration updates**: Modify YAML for new requirements
- **Script improvements**: Update individual software scripts
- **System maintenance**: Clean package caches and temporary files

### Best Practices
- **Version control**: Track configuration changes
- **Testing**: Validate changes before deployment
- **Documentation**: Update configs and maintain team knowledge
- **Backup**: Save working configurations before major changes

## 🤝 Community and Support

### Getting Help
- **Documentation**: Comprehensive guides in this directory
- **Troubleshooting**: Common issues and solutions documented
- **GitHub Issues**: Report bugs and request features
- **GitHub Discussions**: Ask questions and share experiences

### Contributing
- **Add Software**: Create installation scripts for new tools
- **Improve Scripts**: Enhance existing installations
- **Documentation**: Help improve guides and examples
- **Testing**: Verify compatibility and report issues

## 📈 Performance Considerations

### Optimization Features
- **Temp Directory Mode**: Fast installation via temporary file copying
- **Parallel Operations**: Multiple downloads and installations
- **Caching**: Package cache reuse and dependency optimization
- **Selective Installation**: Install only needed components

### Resource Management
- **Disk Space**: Automatic cleanup after installation
- **Memory Usage**: Efficient processing of large installations
- **Network Bandwidth**: Optimal download strategies
- **Time Efficiency**: Streamlined installation process

---

This documentation provides everything needed to successfully use, configure, and extend the WSL Ubuntu DevBox Installer. Whether you're a new user getting started or an experienced developer adding new features, these guides will help you accomplish your goals efficiently.
