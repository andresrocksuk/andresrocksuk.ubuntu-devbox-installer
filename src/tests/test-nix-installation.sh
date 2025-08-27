#!/bin/bash

# test-nix-installation.sh - Test script for Nix flake installation

set -e

echo "🧪 Testing Nix Flake Installation"
echo "=================================="

# Test 1: Check if Nix is available
echo "📋 Test 1: Checking Nix availability..."
if command -v nix >/dev/null 2>&1; then
    echo "✅ Nix is available"
    echo "   Version: $(nix --version)"
else
    echo "❌ Nix is not available"
    exit 1
fi

# Test 2: Check if hello is available
echo ""
echo "📋 Test 2: Checking hello command..."
if command -v hello >/dev/null 2>&1; then
    echo "✅ hello command is available"
    echo "   Testing hello:"
    hello | head -3
else
    echo "❌ hello command is not available"
fi

# Test 3: Check if figlet is available
echo ""
echo "📋 Test 3: Checking figlet command..."
if command -v figlet >/dev/null 2>&1; then
    echo "✅ figlet command is available"
    echo "   Testing figlet:"
    echo "WSL Rocks!" | figlet
else
    echo "❌ figlet command is not available"
fi

# Test 4: List Nix profiles
echo ""
echo "📋 Test 4: Checking Nix profiles..."
if nix profile list >/dev/null 2>&1; then
    echo "✅ Nix profiles accessible"
    echo "   Installed packages:"
    nix profile list
else
    echo "⚠️  Could not list Nix profiles"
fi

# Test 5: Check if flake directory exists
echo ""
echo "📋 Test 5: Checking flake directory..."
FLAKE_DIR="$(dirname "$0")/examples/basic-flake"
if [ -f "$FLAKE_DIR/flake.nix" ]; then
    echo "✅ Basic flake found at $FLAKE_DIR"
    echo "   Flake info:"
    cd "$FLAKE_DIR"
    nix flake metadata 2>/dev/null || echo "   Could not get flake metadata"
    cd - >/dev/null
else
    echo "❌ Basic flake not found at $FLAKE_DIR"
fi

echo ""
echo "🎉 Nix installation test completed!"
