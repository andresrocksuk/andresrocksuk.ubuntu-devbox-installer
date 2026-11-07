#!/bin/bash

# test-taskfile-installation.sh - Verifies Taskfile CLI installation script and configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../custom-software/taskfile/install.sh"
CONFIG_FILE="$SCRIPT_DIR/../config-profiles/full-install.yaml"
VERSION_CHECKER="$SCRIPT_DIR/../utils/version-checker.sh"

echo "🧪 Running Taskfile CLI Integration Tests"
echo "=========================================="

FAILED=0

# Test 1: Validate script existence and permissions
echo "📋 Test 1: Checking script existence and executable permissions..."
if [ ! -f "$TARGET_SCRIPT" ]; then
    echo "❌ FAIL: $TARGET_SCRIPT does not exist"
    FAILED=$((FAILED + 1))
elif [ ! -x "$TARGET_SCRIPT" ]; then
    echo "❌ FAIL: $TARGET_SCRIPT is not executable"
    FAILED=$((FAILED + 1))
else
    echo "✅ PASS: $TARGET_SCRIPT exists and is executable"
fi

# Test 2: Check bash syntax with bash -n
echo "📋 Test 2: Validating bash syntax..."
if bash -n "$TARGET_SCRIPT"; then
    echo "✅ PASS: $TARGET_SCRIPT has valid syntax"
else
    echo "❌ FAIL: $TARGET_SCRIPT syntax check failed"
    FAILED=$((FAILED + 1))
fi

# Test 3: Check framework integration and security practices
echo "📋 Test 3: Checking framework and safety conventions..."
if grep -q "installation-framework.sh" "$TARGET_SCRIPT" && \
   grep -q "security-helpers.sh" "$TARGET_SCRIPT" && \
   grep -q "package-manager.sh" "$TARGET_SCRIPT" && \
   grep -q "set -e" "$TARGET_SCRIPT"; then
    echo "✅ PASS: Script integrates installation-framework, security-helpers, package-manager, and set -e"
else
    echo "❌ FAIL: Missing required framework or safety inclusions in $TARGET_SCRIPT"
    FAILED=$((FAILED + 1))
fi

# Test 4: Validate YAML configuration registration
echo "📋 Test 4: Validating full-install.yaml registration..."
if command -v yq >/dev/null 2>&1; then
    taskfile_entry=$(yq eval '.custom_software[] | select(.name == "taskfile")' "$CONFIG_FILE" 2>/dev/null || true)
    if [ -n "$taskfile_entry" ]; then
        cmd=$(yq eval '.custom_software[] | select(.name == "taskfile") | .version_command' "$CONFIG_FILE" 2>/dev/null)
        flag=$(yq eval '.custom_software[] | select(.name == "taskfile") | .version_flag' "$CONFIG_FILE" 2>/dev/null)
        if [ "$cmd" = "task" ] && [ "$flag" = "--version" ]; then
            echo "✅ PASS: taskfile correctly configured in full-install.yaml (cmd: $cmd, flag: $flag)"
        else
            echo "❌ FAIL: taskfile entry has unexpected command ($cmd) or flag ($flag)"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "❌ FAIL: taskfile not found in custom_software section of $CONFIG_FILE"
        FAILED=$((FAILED + 1))
    fi
else
    echo "⚠️ SKIP: yq command not available for YAML validation"
fi

# Test 5: Validate version-checker support
echo "📋 Test 5: Checking version-checker.sh support for task..."
if grep -q '"task")' "$VERSION_CHECKER"; then
    echo "✅ PASS: version-checker.sh contains explicit case handler for task"
else
    echo "❌ FAIL: version-checker.sh does not contain explicit case handler for task"
    FAILED=$((FAILED + 1))
fi

# Test 6: Validate root Taskfile.yml
echo "📋 Test 6: Checking root Taskfile.yml..."
if [ -f "$REPO_ROOT/Taskfile.yml" ]; then
    if grep -q "version: '3'" "$REPO_ROOT/Taskfile.yml" && grep -q "test:" "$REPO_ROOT/Taskfile.yml"; then
        echo "✅ PASS: Root Taskfile.yml exists and defines tasks"
    else
        echo "❌ FAIL: Root Taskfile.yml is missing version or test tasks"
        FAILED=$((FAILED + 1))
    fi
else
    echo "❌ FAIL: Root Taskfile.yml does not exist"
    FAILED=$((FAILED + 1))
fi

# Test 7: Functional sandbox installation test
echo "📋 Test 7: Running functional sandbox installation test..."
SANDBOX_DIR="$(mktemp -d)"
FAKE_BIN_DIR="$SANDBOX_DIR/fake-bin"
FAKE_LOCAL_BIN="$SANDBOX_DIR/usr/local/bin"
FAKE_COMPLETIONS_BASH="$SANDBOX_DIR/etc/bash_completion.d"
FAKE_COMPLETIONS_ZSH="$SANDBOX_DIR/usr/local/share/zsh/site-functions"

cleanup() {
    rm -rf "$SANDBOX_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_BIN_DIR" "$FAKE_LOCAL_BIN" "$FAKE_COMPLETIONS_BASH" "$FAKE_COMPLETIONS_ZSH"

# Create mock sudo that routes to target directory without needing root
cat > "$FAKE_BIN_DIR/sudo" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 0 ] && [ "$1" = "-n" ]; then
    shift
fi

# Intercept mv or mkdir or tee for /usr/local/bin or completions
args=()
for arg in "$@"; do
    case "$arg" in
        /usr/local/bin/*)
            args+=("${TEST_SANDBOX_DIR}/usr/local/bin/$(basename "$arg")")
            ;;
        /usr/local/bin)
            args+=("${TEST_SANDBOX_DIR}/usr/local/bin")
            ;;
        /etc/bash_completion.d/*)
            args+=("${TEST_SANDBOX_DIR}/etc/bash_completion.d/$(basename "$arg")")
            ;;
        /etc/bash_completion.d)
            args+=("${TEST_SANDBOX_DIR}/etc/bash_completion.d")
            ;;
        /usr/local/share/zsh/site-functions/*)
            args+=("${TEST_SANDBOX_DIR}/usr/local/share/zsh/site-functions/$(basename "$arg")")
            ;;
        /usr/local/share/zsh/site-functions)
            args+=("${TEST_SANDBOX_DIR}/usr/local/share/zsh/site-functions")
            ;;
        *)
            args+=("$arg")
            ;;
    esac
done

exec "${args[@]}"
EOF
chmod +x "$FAKE_BIN_DIR/sudo"

# Execute installer inside isolated sandbox environment
export TEST_SANDBOX_DIR="$SANDBOX_DIR"
export PATH="$FAKE_BIN_DIR:$FAKE_LOCAL_BIN:$PATH"

if FORCE_INSTALL=true bash "$TARGET_SCRIPT"; then
    echo "✅ PASS: Installer executed successfully"
else
    echo "❌ FAIL: Installer exited with non-zero status"
    FAILED=$((FAILED + 1))
fi

# Verify binary was placed in the mock /usr/local/bin
if [ -x "$FAKE_LOCAL_BIN/task" ]; then
    echo "✅ PASS: task binary installed to destination and is executable"
    
    # Test task version
    task_ver=$("$FAKE_LOCAL_BIN/task" --version 2>/dev/null || true)
    if echo "$task_ver" | grep -qE '[0-9]+\.[0-9]+'; then
        echo "✅ PASS: task --version reported valid version: $task_ver"
    else
        echo "❌ FAIL: task --version output unexpected: $task_ver"
        FAILED=$((FAILED + 1))
    fi

    # Test running a task with Taskfile.yml
    TEST_TASKFILE_DIR="$SANDBOX_DIR/taskfile-test"
    mkdir -p "$TEST_TASKFILE_DIR"
    cat > "$TEST_TASKFILE_DIR/Taskfile.yml" << 'EOF'
version: '3'
tasks:
  hello:
    cmds:
      - echo "hello-from-task"
    silent: true
EOF
    task_output=$(cd "$TEST_TASKFILE_DIR" && "$FAKE_LOCAL_BIN/task" hello 2>/dev/null || true)
    if [ "$task_output" = "hello-from-task" ]; then
        echo "✅ PASS: task executed sample Taskfile.yml task successfully"
    else
        echo "❌ FAIL: task execution output expected 'hello-from-task', got '$task_output'"
        FAILED=$((FAILED + 1))
    fi
else
    echo "❌ FAIL: task binary not found in $FAKE_LOCAL_BIN"
    FAILED=$((FAILED + 1))
fi

# Test 8: Test idempotency (running again when already installed)
echo "📋 Test 8: Checking idempotency (second run when task already installed)..."
if bash "$TARGET_SCRIPT"; then
    echo "✅ PASS: Second run succeeded without error (idempotent)"
else
    echo "❌ FAIL: Second run failed"
    FAILED=$((FAILED + 1))
fi

echo "=========================================="
if [ "$FAILED" -eq 0 ]; then
    echo "🎉 All Taskfile integration tests passed!"
    exit 0
else
    echo "❌ $FAILED test(s) failed."
    exit 1
fi
