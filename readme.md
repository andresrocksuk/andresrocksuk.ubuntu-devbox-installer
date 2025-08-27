# WSL Ubuntu DevBox Installer

A declarative WSL development environment installer that automates Ubuntu 24.04 LTS setup from Windows PowerShell. This system uses YAML configuration to orchestrate software installations via multiple package managers (apt, custom scripts, Nix) with comprehensive logging and error handling.

## ✨ Key Features

- 🎯 **Declarative Configuration**: Define your entire development environment in YAML
- 🔄 **Idempotent Installations**: Safe to run multiple times, skips already installed software
- 📦 **Multi-Package Manager Support**: apt, pip/pipx, PowerShell modules, Nix flakes, and custom scripts
- 🛠️ **15+ Pre-built Software Scripts**: Docker, Node.js, Go, Terraform, Kubernetes tools, and more
- 🔍 **Comprehensive Testing**: Built-in verification framework with detailed reporting
- 📊 **Advanced Logging**: Single-run ID system for easy troubleshooting and correlation
- 🚀 **Windows Integration**: PowerShell-based WSL management and reset capabilities
- ⚡ **Performance Optimized**: Temp directory execution for faster installations

## 🚀 Quick Start

### Prerequisites

- Windows 10/11 with WSL 2 enabled
- PowerShell 5.1 or newer
- Administrator privileges for WSL management

### Remote Installation (Recommended)

**One-liner installation** - No need to clone the repository:

```powershell
irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/main/install-wsl-remote.ps1" | iex
```

For advanced options, see the [Remote Installation Guide](docs/remote-installation.md).

### Local Installation

1. **Clone the repository:**

   ```powershell
   git clone https://github.com/andresrocksuk/ubuntu-devbox-installer.git
   cd ubuntu-devbox-installer
   ```

2. **Run the installer:**

   ```powershell
   # Full installation with user creation
   .\install-wsl.ps1 -AutoInstall
   
   # Reset WSL and install fresh
   .\install-wsl.ps1 -ResetWSL -AutoInstall
   ```

3. **Verify installation:**

   ```powershell
   .\test-installation-wsl.ps1
   ```

## 📋 Available Software

The default configuration includes:

### Development Tools

- **Languages**: Python 3, Node.js LTS, Go, .NET SDK 8
- **Version Control**: Git with oh-my-zsh integration
- **Editors**: Neovim with basic configuration
- **Shells**: Zsh with oh-my-zsh framework

### DevOps & Cloud Tools

- **Containers**: Docker Engine, Docker Compose
- **Kubernetes**: kubectl, Helm, k9s
- **Infrastructure**: Terraform, OpenTofu
- **Cloud**: Azure CLI, Azure DevOps CLI
- **Package Managers**: Homebrew, Nix

### System Utilities

- **CLI Tools**: bat, fzf, zoxide, fastfetch, yq, jq
- **Build Tools**: build-essential, unzip, zip
- **Monitoring**: htop, tree

## 🎛️ Configuration Options

### Using Example Configurations

```powershell
# Minimal developer setup
.\install-wsl.ps1 -AutoInstall -Config @("src/examples/minimal-dev.yaml")

# Data science environment
.\install-wsl.ps1 -AutoInstall -Config @("src/examples/data-science.yaml")
```

### Selective Installation

```powershell
# Install only specific sections
.\install-wsl.ps1 -AutoInstall -Config @("prerequisites","apt_packages")

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

### Advanced Options

```bash
# From within WSL - dry run to see what would be installed
./src/install.sh --dry-run

# Force reinstall everything
./src/install.sh --force

# Install with debug logging
./src/install.sh --log-level DEBUG

# Use custom configuration
./src/install.sh --config examples/minimal-dev.yaml
```

## 🧪 Testing & Verification

```powershell
# Test all installations
.\test-installation-wsl.ps1

# From within WSL - test specific software
./src/tests/test-installation.sh --software "docker,nodejs,git"

# Generate detailed report
./src/tests/test-installation.sh --report
```

## 📁 Project Structure

```
ubuntu-devbox-installer/
├── install-wsl.ps1              # Main PowerShell orchestrator
├── test-installation-wsl.ps1    # PowerShell test wrapper
├── src/
│   ├── install.sh               # Main installation engine
│   ├── install.yaml             # Default configuration
│   ├── software-scripts/        # Individual software installers
│   │   ├── docker/
│   │   ├── nodejs/
│   │   ├── golang/
│   │   └── [13 more...]
│   ├── utils/                   # Core utilities
│   │   ├── logger.sh
│   │   ├── package-manager.sh
│   │   └── version-checker.sh
│   └── tests/                   # Testing framework
├── examples/                    # Example configurations
│   ├── minimal-dev.yaml
│   ├── data-science.yaml
│   └── basic-flake/
└── docs/                       # Documentation
```

## 📊 Logging & Troubleshooting

All operations use a unique run ID for log correlation:

```
src/utils/logs/
├── wsl-installation-20250827_120000.log    # Main installation log
├── installation-report-20250827_120000.txt # Version report
└── test-results-20250827_120000.txt        # Test results
```

Common troubleshooting steps:

1. **Check logs**: Look for errors in the installation log file
2. **Re-run installation**: The system is idempotent and safe to retry
3. **Test specific software**: Use targeted testing to isolate issues
4. **Reset if needed**: Use `.\install-wsl.ps1 -ResetWSL` for clean slate

## 🔧 Customization

### Adding New Software

1. Create installation script:
   ```bash
   mkdir src/software-scripts/my-tool
   # Create src/software-scripts/my-tool/install.sh
   ```

2. Add to configuration:
   ```yaml
   custom_software:
     - name: my-tool
       description: "My custom tool"
       script: my-tool/install.sh
   ```

3. Test the installation:
   ```powershell
   .\install-wsl.ps1 -AutoInstall -Config custom_software
   ```

### Creating Custom Configurations

Copy and modify existing configurations:

```bash
cp src/install.yaml my-config.yaml
# Edit my-config.yaml for your needs
./src/install.sh --config my-config.yaml
```

## 📚 Documentation

- [Installation Guide](docs/installation-guide.md) - Detailed setup instructions
- [Configuration Reference](docs/configuration-reference.md) - YAML schema and options
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions
- [API Reference](docs/api-reference.md) - Utility functions and scripting
- [Contributing Guide](docs/contributing.md) - How to extend the system

## 🤝 Contributing

Contributions are welcome! Please read the [Contributing Guide](docs/contributing.md) for details on:

- Adding new software installations
- Improving existing scripts
- Documentation updates
- Testing procedures

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for WSL 2 and Ubuntu 24.04 LTS
- Inspired by declarative infrastructure tools
- Community-driven software selection
- Optimized for developer productivity

---

**Production Ready**: This system has been thoroughly tested and is ready for production use in team development environment standardization.
