#!/bin/bash

# environment-detector.sh - Centralized environment detection utility
# Detects whether the script is running in WSL, a native Ubuntu VM, or a container

# Prevent double-sourcing
if [ "${_ENVIRONMENT_DETECTOR_LOADED:-false}" = "true" ]; then
    return 0 2>/dev/null || true
fi
_ENVIRONMENT_DETECTOR_LOADED=true

# Environment type constants
readonly ENV_TYPE_WSL="wsl"
readonly ENV_TYPE_NATIVE="native"
readonly ENV_TYPE_CONTAINER="container"

# Cached environment type (set once, reused)
_DETECTED_ENV_TYPE=""

# Detect if running inside WSL (Windows Subsystem for Linux)
# Returns 0 if WSL, 1 otherwise
is_wsl_environment() {
    if [ -f /proc/version ] && grep -qi "Microsoft\|WSL" /proc/version 2>/dev/null; then
        return 0
    fi
    # Additional WSL indicators
    if [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSLENV:-}" ]; then
        return 0
    fi
    return 1
}

# Detect if running inside a Docker container
# Returns 0 if container, 1 otherwise
is_container_environment() {
    # Check for .dockerenv file (Docker)
    if [ -f /.dockerenv ]; then
        return 0
    fi
    # Check cgroup for docker/containerd/lxc indicators
    if [ -f /proc/1/cgroup ] && grep -qi "docker\|containerd\|lxc" /proc/1/cgroup 2>/dev/null; then
        return 0
    fi
    # Check for container environment variable (set by some runtimes)
    if [ -n "${container:-}" ]; then
        return 0
    fi
    # Check if PID 1 is not systemd/init (common in containers)
    if [ -f /proc/1/sched ] && head -n1 /proc/1/sched 2>/dev/null | grep -q "bash\|sh\|sleep\|node\|python"; then
        return 0
    fi
    return 1
}

# Detect if running on a native Ubuntu/Linux host (bare metal or VM, not WSL or container)
# Returns 0 if native, 1 otherwise
is_native_environment() {
    if ! is_wsl_environment && ! is_container_environment; then
        return 0
    fi
    return 1
}

# Get the detected environment type as a string
# Returns one of: "wsl", "native", "container"
get_environment_type() {
    if [ -n "$_DETECTED_ENV_TYPE" ]; then
        echo "$_DETECTED_ENV_TYPE"
        return 0
    fi

    if is_wsl_environment; then
        _DETECTED_ENV_TYPE="$ENV_TYPE_WSL"
    elif is_container_environment; then
        _DETECTED_ENV_TYPE="$ENV_TYPE_CONTAINER"
    else
        _DETECTED_ENV_TYPE="$ENV_TYPE_NATIVE"
    fi

    echo "$_DETECTED_ENV_TYPE"
}

# Check if systemd is available and running as init system
# Returns 0 if systemd is available, 1 otherwise
has_systemd() {
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        return 0
    fi
    return 1
}

# Check if Docker Desktop WSL integration is providing Docker
# Returns 0 if Docker Desktop WSL integration is detected, 1 otherwise
is_docker_desktop_integration() {
    if ! is_wsl_environment; then
        return 1
    fi
    local docker_path
    docker_path=$(command -v docker 2>/dev/null || echo "")
    if [[ "$docker_path" == *"/mnt/c/"* ]] || [[ "$docker_path" == *"Program Files"* ]]; then
        return 0
    fi
    return 1
}

# Log the detected environment (requires logger.sh to be sourced)
log_environment_info() {
    local env_type
    env_type=$(get_environment_type)

    if command -v log_info >/dev/null 2>&1; then
        log_info "Detected environment type: $env_type"
        if [ "$env_type" = "$ENV_TYPE_WSL" ]; then
            log_info "WSL distribution: ${WSL_DISTRO_NAME:-unknown}"
            if is_docker_desktop_integration; then
                log_info "Docker Desktop WSL integration detected"
            fi
        elif [ "$env_type" = "$ENV_TYPE_CONTAINER" ]; then
            log_info "Running inside a container"
        else
            log_info "Running on native Linux (bare metal or VM)"
        fi
        if has_systemd; then
            log_info "Systemd is available"
        else
            log_info "Systemd is NOT available"
        fi
    fi
}
