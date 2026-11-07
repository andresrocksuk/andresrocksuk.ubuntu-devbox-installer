# Taskfile CLI Tool (`task`) Documentation

## Overview

[Task](https://taskfile.dev/) is a modern task runner / build automation tool that aims to be simpler and easier to use than GNU Make. It is written in Go and uses a clean, expressive YAML format (`Taskfile.yml`) to define tasks, dependencies, environment variables, and commands.

In this repository, Task is integrated as a custom software component that can be installed system-wide on Ubuntu 24.04 LTS (WSL and remote environments).

---

## Installation Strategy & Architecture

### Evaluation of Installation Approaches

| Approach | Method | Pros | Cons | Verdict |
| :--- | :--- | :--- | :--- | :--- |
| **Official Install Script** | `https://taskfile.dev/install.sh` | • Recommended by Task authors<br>• Uses GoReleaser godownloader<br>• Verifies SHA-256 checksums automatically<br>• Auto-detects OS and architecture | Requires outbound internet access during installation | **Primary (Selected)** |
| **Direct GitHub Release Archive** | `https://github.com/go-task/task/releases` | • Direct binary download (`task_linux_${arch}.tar.gz`)<br>• No intermediary redirect services | Requires manual version lookup or fallback | **Secondary Fallback (Selected)** |
| **Cloudsmith APT Repository** | `dl.cloudsmith.io/public/task/task/setup.deb.sh` | • Standard apt package management | • Requires adding third-party repo script<br>• Keyring deprecation warnings in Ubuntu 24.04<br>• Risk of dpkg trigger hanging | *Not Recommended* |
| **Snap / Nix / Homebrew** | Package managers | • Managed dependencies | • Snap requires systemd daemon inside WSL<br>• Homebrew/Nix are secondary package managers in this setup | *Not Recommended for core binary* |

### Implemented Installation Approach

The installation script (`src/custom-software/taskfile/install.sh`) uses a robust hybrid pattern:
1. **Pre-check**: Checks if `task` is already present in PATH using `command -v task` and version checking (skips download if present, unless `FORCE_INSTALL=true`).
2. **Primary**: Downloads the official installation script from `https://taskfile.dev/install.sh` into a secure temporary directory (`chmod 700`), runs it with destination flag `-b`, verifying checksums automatically.
3. **Fallback**: If the official script cannot be reached, falls back to direct release archive retrieval from GitHub releases (`go-task/task`).
4. **Placement**: Installs the validated binary to `/usr/local/bin/task` with `755` permissions for system-wide availability.
5. **Autocompletion**: Automatically sets up shell completion for:
   - **Bash**: `/etc/bash_completion.d/task`
   - **Zsh**: `/usr/local/share/zsh/site-functions/_task`
6. **Verification**: Tests `task --help` and confirms exit code and version extraction.

---

## Configuration Reference

Taskfile is registered in `src/config-profiles/full-install.yaml` under `custom_software`:

```yaml
custom_software:
  - name: taskfile
    description: "Task runner and build tool"
    script: custom-software/taskfile/install.sh
    version_command: task
    version_flag: --version
```

### Script Execution Modes

The script supports both orchestrator execution and standalone execution:

```bash
# Standalone execution
bash src/custom-software/taskfile/install.sh

# Force reinstallation
FORCE_INSTALL=true bash src/custom-software/taskfile/install.sh
```

---

## Repository Taskfile (`Taskfile.yml`)

The repository includes a root `Taskfile.yml` providing standard automation targets for development and testing:

```bash
# List available tasks
task --list

# Run shell script syntax validation
task lint

# Validate all YAML profiles
task validate:yaml

# Run dedicated Taskfile integration tests
task test:taskfile

# Run security tests
task test:security

# Run the full test suite
task test

# Perform a dry-run installation
task dry-run
```

---

## Verification & Testing

A dedicated test suite is located at `src/tests/test-taskfile-installation.sh`:

```bash
# Run the dedicated test script
bash src/tests/test-taskfile-installation.sh
```

This test validates:
- Script presence, permissions, and bash syntax (`bash -n`)
- Inclusion of required security and installation framework helpers
- Registration in `full-install.yaml` and case handling in `version-checker.sh`
- Isolated sandbox installation with mock root permissions
- Verification of binary version extraction (`task --version`)
- Execution of real Taskfile commands
- Idempotency on subsequent runs
