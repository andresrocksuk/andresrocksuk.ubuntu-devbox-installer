#!/bin/bash

# test-azure-devops-cli.sh - Verifies shared Azure DevOps CLI extension installation behavior

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../custom-software/azure-devops-cli/install.sh"

TEMP_DIR="$(mktemp -d)"
FAKE_BIN_DIR="$TEMP_DIR/fake-bin"
FAKE_USR_BIN_DIR="$TEMP_DIR/usr/bin"
FAKE_LOCAL_BIN_DIR="$TEMP_DIR/usr/local/bin"
FAKE_EXTENSION_DIR="$TEMP_DIR/usr/local/share/azure-cli/cliextensions"
FAKE_PROFILE_PATH="$TEMP_DIR/etc/profile.d/azure-cli-extensions.sh"
FAKE_ENV_PATH="$TEMP_DIR/etc/environment.d/azure-cli-extensions.conf"
FAKE_HOME="$TEMP_DIR/home/tester"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_BIN_DIR" "$FAKE_USR_BIN_DIR" "$FAKE_LOCAL_BIN_DIR" "$(dirname "$FAKE_PROFILE_PATH")" "$(dirname "$FAKE_ENV_PATH")" "$FAKE_HOME"

cat > "$FAKE_BIN_DIR/sudo" << 'EOF'
#!/bin/bash
set -euo pipefail

if [ "$#" -gt 0 ] && [ "$1" = "-n" ]; then
    shift
fi

exec "$@"
EOF
chmod +x "$FAKE_BIN_DIR/sudo"

cat > "$FAKE_USR_BIN_DIR/az" << 'EOF'
#!/bin/bash
set -euo pipefail

extension_dir="${AZURE_EXTENSION_DIR:-$HOME/.azure/cliextensions}"
extension_version_file="$extension_dir/azure-devops/version.txt"

if [ "$#" -eq 0 ]; then
    exit 1
fi

case "$1" in
    --version)
        echo "azure-cli                         2.85.0"
        exit 0
        ;;
    extension)
        shift
        case "${1:-}" in
            show)
                if [ -f "$extension_version_file" ]; then
                    cat "$extension_version_file"
                    exit 0
                fi
                exit 1
                ;;
            add)
                mkdir -p "$(dirname "$extension_version_file")"
                printf '1.0.2\n' > "$extension_version_file"
                exit 0
                ;;
            update)
                if [ -f "$extension_version_file" ]; then
                    exit 0
                fi
                exit 1
                ;;
            *)
                exit 1
                ;;
        esac
        ;;
    *)
        exit 1
        ;;
esac
EOF
chmod +x "$FAKE_USR_BIN_DIR/az"

PATH="$FAKE_LOCAL_BIN_DIR:$FAKE_BIN_DIR:$FAKE_USR_BIN_DIR:$PATH" \
HOME="$FAKE_HOME" \
AZURE_DEVOPS_NATIVE_AZ_PATH="$FAKE_USR_BIN_DIR/az" \
AZURE_DEVOPS_AZ_WRAPPER_PATH="$FAKE_LOCAL_BIN_DIR/az" \
AZURE_DEVOPS_EXTENSION_DIR="$FAKE_EXTENSION_DIR" \
AZURE_DEVOPS_PROFILE_SCRIPT_PATH="$FAKE_PROFILE_PATH" \
AZURE_DEVOPS_ENV_CONFIG_PATH="$FAKE_ENV_PATH" \
bash "$TARGET_SCRIPT"

if [ ! -x "$FAKE_LOCAL_BIN_DIR/az" ]; then
    echo "❌ FAIL: Azure CLI wrapper was not created"
    exit 1
fi

if [ ! -f "$FAKE_EXTENSION_DIR/azure-devops/version.txt" ]; then
    echo "❌ FAIL: Azure DevOps extension was not installed to shared directory"
    exit 1
fi

if ! grep -q 'AZURE_EXTENSION_DIR=' "$FAKE_PROFILE_PATH"; then
    echo "❌ FAIL: Profile script does not export AZURE_EXTENSION_DIR"
    exit 1
fi

if ! grep -q 'AZURE_EXTENSION_DIR=' "$FAKE_ENV_PATH"; then
    echo "❌ FAIL: Environment configuration does not export AZURE_EXTENSION_DIR"
    exit 1
fi

extension_version=$(PATH="$FAKE_LOCAL_BIN_DIR:$FAKE_BIN_DIR:$FAKE_USR_BIN_DIR:$PATH" HOME="$FAKE_HOME" az extension show --name azure-devops --query version -o tsv)

if [ "$extension_version" != "1.0.2" ]; then
    echo "❌ FAIL: Expected Azure DevOps extension version 1.0.2, got $extension_version"
    exit 1
fi

echo "✅ PASS: Azure DevOps CLI shared extension installation works"
