# WSL Ubuntu DevBox Installer - AI Coding Agent Instructions

## Project Overview
This is a declarative WSL development environment installer that automates Ubuntu 24.04 LTS setup from Windows PowerShell. The system uses YAML configuration to orchestrate software installations via multiple package managers (apt, custom scripts, Nix) with comprehensive logging and error handling.

## Architecture Components

### Core Installation Flow
- **Entry Point**: `install-wsl.ps1` - PowerShell orchestrator that manages WSL distribution and copies installation to temp directory for performance
- **Main Engine**: `src/install.sh` - Bash script that parses `install.yaml` and coordinates all installations
- **Configuration**: `src/install.yaml` - Declarative YAML defining packages, prerequisites, and settings
- **Utilities**: `src/utils/` - Shared libraries for logging, package management, and version checking

### Software Installation Pattern
Each software has a dedicated script in `src/software-scripts/{name}/install.sh` that follows this structure:
```bash
# Standard pattern: check if installed, install if missing, verify installation
if command -v docker >/dev/null 2>&1; then
    log_info "Docker already installed"
    return 0
fi
# Installation logic here
```

### Logging & Execution Context
- All operations use run IDs (`WSL_INSTALL_RUN_ID`) for log correlation
- Logs are written to temp directory during execution, then copied to `src/utils/logs/`
- Two execution modes: direct (slower) and temp-copy (default, faster)

## Key Development Patterns

### YAML Configuration Structure
```yaml
metadata:      # Project info and versioning
prerequisites: # System packages installed first
apt_packages:  # Ubuntu packages with version specs
custom_software: # References to software-scripts/ folders
nix_packages:  # Nix flake packages
configurations: # Post-install configuration steps
```

### Utility Function Usage
- Always source utilities: `source "$UTILS_DIR/logger.sh"`
- Use logging functions: `log_info`, `log_error`, `log_success`, `log_section`
- Package operations: `install_apt_package`, `check_version`, `command_exists`

### Error Handling Strategy
- Individual software failures don't stop overall installation (continue_on_error: true)
- Each installation tracked in `INSTALLATION_SUMMARY` and `FAILED_INSTALLATIONS` arrays
- Comprehensive exit status reporting

## Critical Workflows

### Adding New Software
1. Create `src/software-scripts/{name}/install.sh` 
2. Follow existing pattern: check → install → verify
3. Add entry to `install.yaml` under `custom_software` section
4. Test with `./install-wsl.ps1 -AutoInstall -Config custom_software`

### Testing Installations
- Full test: `.\test-installation-wsl.ps1` (PowerShell wrapper)
- Specific software: `src/tests/test-installation.sh -s docker,nodejs`
- Generate reports: `src/tests/test-installation.sh -r`

### Configuration Management
- Main config: `src/install.yaml` (comprehensive setup)
- Examples: `examples/{minimal-dev,data-science}.yaml` for specific use cases
- Nix integration: `src/install.flake.nix` for reproducible package management

### Log Analysis
- Installation logs: `src/utils/logs/wsl-installation-{RUNID}.log`
- System reports: `src/utils/logs/installation-report-{RUNID}.txt`
- Use run ID to correlate logs across multiple files

## Important Conventions

### File Paths & Sourcing
- Scripts use `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"` for reliable path resolution
- Utilities sourced relatively: `source "$UTILS_DIR/logger.sh"`
- All paths should be absolute when calling between components

### Version Checking
- Use `check_version_requirement` function for version comparisons
- Store detected versions in logs for troubleshooting
- Software detection via `command -v` before installation attempts

### PowerShell-WSL Integration
- PowerShell converts Windows paths to WSL format: `$wslSourcePath = $PSScriptRoot -replace "C:", "/mnt/c" -replace "\\", "/"`
- Use `-AutoInstall` for non-interactive execution
- `-ResetWSL` flag for clean installations (destructive)

### Nix Integration
- Nix packages installed via flakes in `install.flake.nix`
- Standard flake structure with packages, devShells, and apps
- Integration requires prior Nix installation via `nix/install.sh`

## Implementation Planning Process
When implementing new features:
1. Create implementation plan in `.github/docs/` with date and feature name
2. Break down into task groups with checkboxes for progress tracking
3. Follow logical task sequence respecting dependencies
4. Update `changelog.md` upon completion with summary of changes having executive summary and technical summary
5. Latest updates done to the changelog should be added at the top of the file
6. Generate final documentation in `docs/` directory

## Bash and PowerShell Scripts Security
When implementing or modifying bash scripts, follow these security best practices:
1. Always validate and sanitize inputs using regex patterns to allow only expected characters.
2. Do not use eval or similar functions to execute dynamically constructed commands unless absolutely necessary and safe.
3. Use double quotes around variable expansions to prevent word splitting and globbing.
4. Avoid passing untrusted input directly to shell commands.
5. Implement error handling to catch and log unexpected behavior.
6. Regularly review and test scripts for vulnerabilities, especially when handling external inputs.

## Test Scripts
- Create dedicated test scripts in `src/tests/` for scripts.

When modifying this codebase, maintain the modular software-scripts structure, preserve the logging patterns for troubleshooting, and ensure all new configurations follow the YAML schema established in existing examples.

To be sure that this instructions are followed, include at the beginning of your explanations "[Following your instructions]"