# Taskfile (Task) CLI Tool Integration Plan

**Date**: 2026-11-07  
**Feature**: Task CLI (`taskfile`) Integration  
**Reference**: [Task Official Documentation](https://taskfile.dev/)  

---

## 1. Overview & Installation Approach Evaluation

Task (`task`) is a modern task runner and build automation tool written in Go that uses concise, declarative YAML files (`Taskfile.yml`).

### Evaluation of Installation Approaches

1. **Official Installation Script (`https://taskfile.dev/install.sh`)** [Recommended & Selected]:
   - **Mechanism**: The official script provided by the upstream Task project (powered by GoReleaser godownloader).
   - **Security**: Verifies SHA-256 checksums from `task_checksums.txt` automatically before binary installation.
   - **Cross-Architecture**: Auto-detects `linux/amd64`, `linux/arm64`, and other architectures.
   - **Self-contained**: Installs clean binary to `/usr/local/bin` without package repository overhead or apt keyring conflicts on Ubuntu 24.04.

2. **Direct GitHub Release Binary Download with Checksum Verification** [Fallback]:
   - **Mechanism**: Direct fetch from `github.com/go-task/task/releases` API/tag.
   - **Use case**: Serves as a robust fallback if `taskfile.dev` domain redirect is unreachable or restricted.

3. **Cloudsmith APT Repository**:
   - Requires adding third-party deb repository (`dl.cloudsmith.io`). In Ubuntu 24.04 (Noble), external repositories can introduce GPG keyring depreciation warnings, apt update delays, and potential dpkg trigger hangs. Not recommended over verified binary installation.

4. **Package Managers (Snap / Homebrew / Nix)**:
   - Snap requires systemd snapd daemon inside WSL (often disabled or resource-heavy).
   - Homebrew and Nix are secondary package managers within this devbox environment; installing Task as a primary core binary in `/usr/local/bin` ensures it is available globally to all users and shells.

---

## 2. Implementation Tasks

### Group 1: Research & Installation Strategy
- [x] Research official installation methods from https://taskfile.dev/
- [x] Test official installer script and binary architecture support
- [x] Finalize hybrid strategy: official installer script with fallback to direct release download and checksum validation

### Group 2: Custom Software Implementation
- [x] Create `src/custom-software/taskfile/install.sh`
- [x] Source framework utilities (`installation-framework.sh`, `package-manager.sh`, `security-helpers.sh`, `logger.sh`)
- [x] Implement `install_taskfile` function with:
  - Pre-installation check (`command -v task` and version checking)
  - Non-interactive apt preparation (`setup_noninteractive_apt`)
  - Architecture detection (`amd64`, `arm64`, etc.)
  - Secure temporary directory creation
  - Primary installation via verified official install script (`https://taskfile.dev/install.sh`)
  - Secondary fallback via direct GitHub release tarball download
  - Binary installation to `/usr/local/bin/task` with executable permissions
  - Shell autocompletion configuration for bash (`/etc/bash_completion.d/task`) and zsh (`/usr/local/share/zsh/site-functions/_task`)
  - Verification using `verify_installation` and `task --version`
  - Resource cleanup in `trap` / exit handler

### Group 3: Core System Integration
- [x] Register `taskfile` in `src/config-profiles/full-install.yaml` under `custom_software`
- [x] Add `task` command version extraction to `src/utils/version-checker.sh` in `get_command_version()`
- [x] Create a root `Taskfile.yml` for developer convenience in this repository

### Group 4: Testing & Verification
- [x] Create dedicated test script `src/tests/test-taskfile-installation.sh`
- [x] Validate bash syntax with `bash -n` for all modified/added shell scripts
- [x] Run test suite and verify installation, idempotency, and error handling
- [x] Verify integration with `src/tests/test-installation.sh`

### Group 5: Documentation & Changelog
- [x] Create dedicated documentation `docs/taskfile.md`
- [x] Update `docs/configuration-reference.md`
- [x] Update `readme.md` with Task in the Available Software list
- [x] Update `changelog.md` with Executive Summary and Technical Summary at the top
- [ ] Commit all changes locally preserving user authorship (`Andres Castaneda <me@andresrocks.mx>`)
