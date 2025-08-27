# Basic Nix Flake for WSL

This flake provides basic utility packages for a WSL development environment.

## Included Packages

- **hello**: A simple "Hello, World!" program for testing
- **figlet**: ASCII art text generator

## Usage

### Direct Installation
The packages are automatically installed when this flake is processed by the WSL installation system.

### Manual Usage
If you want to use this flake manually:

```bash
# Enter a shell with the packages available
nix develop

# Install packages permanently to your profile
nix profile install .#hello .#figlet

# Or install the combined package
nix profile install .#default

# Run directly without installing
nix run .#hello
nix run .#figlet -- "Hello WSL!"
```

## Examples

```bash
# Test hello
hello

# Create ASCII art
figlet "WSL Rocks!"
```

## Package Details

- **hello**: Simple program that prints "Hello, world!" and other messages
- **figlet**: Creates ASCII art text from input strings, useful for banners and decorative text

Both packages are commonly used for testing and creating eye-catching terminal output.
