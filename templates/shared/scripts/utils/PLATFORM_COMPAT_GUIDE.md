# Platform Compatibility Layer Guide

This guide explains how to use the `platform_compat.sh` library to ensure cross-platform compatibility in bash scripts.

## Overview

The platform compatibility layer (`platform_compat.sh`) provides a comprehensive set of functions for writing bash scripts that work consistently across Linux, macOS, and Windows (WSL/MSYS2/Cygwin).

## Quick Start

To use the platform compatibility layer in your script:

```bash
#!/usr/bin/env bash

# Source the platform compatibility layer
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils/platform_compat.sh"

# Now you can use all the cross-platform functions
OS_TYPE=$(detect_os)
CPU_CORES=$(get_cpu_cores)
```

## Migration Guide

### 1. Platform Detection

**Before:**
```bash
OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
    Linux*)  OS="linux" ;;
    Darwin*) OS="macos" ;;
    MINGW*)  OS="windows" ;;
esac
```

**After:**
```bash
OS_TYPE=$(detect_os)  # Returns: linux, macos, windows, freebsd, or unknown
DISTRO=$(detect_linux_distro)  # For Linux: ubuntu, debian, fedora, arch, etc.
ARCH=$(detect_architecture)  # Returns: x64, x86, arm64, arm
```

### 2. CPU Core Detection

**Before:**
```bash
if [[ "$OS_TYPE" == "Darwin" ]]; then
    JOBS=$(sysctl -n hw.ncpu)
else
    JOBS=$(nproc 2>/dev/null || echo 1)
fi
```

**After:**
```bash
JOBS=$(get_cpu_cores)
```

### 3. Tool Detection

**Before:**
```bash
if command -v cmake >/dev/null 2>&1; then
    CMAKE_BINARY=cmake
fi
```

**After:**
```bash
if command_exists cmake; then
    CMAKE_BINARY=$(find_executable cmake)
    CMAKE_VERSION=$(get_command_version cmake)
fi
```

### 4. Path Handling

**Before:**
```bash
BUILD_DIR="${PROJECT_ROOT}/build"
ABS_PATH="$(cd "$SOME_DIR" && pwd)"
```

**After:**
```bash
BUILD_DIR=$(normalize_path "${PROJECT_ROOT}/build")
ABS_PATH=$(get_absolute_path "$SOME_DIR")
NATIVE_PATH=$(to_native_path "$UNIX_PATH")  # For Windows compatibility
```

### 5. Color Support

**Before:**
```bash
# Hardcoded colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
echo -e "${RED}Error${NC}"
```

**After:**
```bash
# Colors are automatically set up based on terminal capabilities
if supports_color; then
    echo_color "${COLOR_RED}" "Error message"
else
    echo "Error message"
fi

# Or use the logging functions
log_error "Error message"
log_success "Success!"
log_warning "Warning!"
log_info "Information"
```

### 6. File Operations

**Before:**
```bash
mkdir -p "$DIR"
rm -rf "$DIR"
cp -r "$SRC" "$DST"
```

**After:**
```bash
make_directory "$DIR"
remove_directory "$DIR"
copy_recursive "$SRC" "$DST"
```

### 7. Temporary Files

**Before:**
```bash
TEMP_FILE="/tmp/myfile.$$"
TEMP_DIR="/tmp/mydir.$$"
```

**After:**
```bash
TEMP_FILE=$(make_temp_file "myfile")
TEMP_DIR=$(make_temp_dir "mydir")
```

### 8. Downloads

**Before:**
```bash
curl -fsSL "$URL" -o "$OUTPUT" || wget -q -O "$OUTPUT" "$URL"
```

**After:**
```bash
download_file "$URL" "$OUTPUT"
```

### 9. Environment Variables

**Before:**
```bash
export PATH="$PATH:$NEW_DIR"
```

**After:**
```bash
append_to_path "$NEW_DIR"
# or
prepend_to_path "$NEW_DIR"
```

## Available Functions

### Platform Detection
- `detect_os()` - Returns: linux, macos, windows, freebsd, unknown
- `detect_linux_distro()` - Returns: ubuntu, debian, fedora, arch, etc.
- `detect_windows_subsystem()` - Returns: wsl, cygwin, mingw32, mingw64, msys2
- `detect_architecture()` - Returns: x64, x86, arm64, arm

### Path Handling
- `to_native_path()` - Convert to native OS path format
- `to_unix_path()` - Convert to Unix path format
- `get_absolute_path()` - Get absolute path of file/directory
- `normalize_path()` - Normalize path separators

### Tool Detection
- `find_executable()` - Find executable in PATH
- `command_exists()` - Check if command exists
- `get_command_version()` - Get version of a command

### System Information
- `get_cpu_cores()` - Get number of CPU cores
- `get_available_memory()` - Get available memory in MB

### Terminal/Console
- `is_terminal()` - Check if running in a terminal
- `supports_color()` - Check if terminal supports colors
- `get_terminal_width()` - Get terminal width

### File Operations
- `make_directory()` - Create directory with parents
- `remove_directory()` - Remove directory recursively
- `copy_recursive()` - Copy files/directories recursively
- `get_file_mtime()` - Get file modification time

### Environment
- `export_var()` - Export variable (cross-platform)
- `append_to_path()` - Append directory to PATH
- `prepend_to_path()` - Prepend directory to PATH

### Shell Detection
- `detect_shell()` - Detect current shell
- `get_shell_config()` - Get shell configuration file

### Logging
- `log_info()` - Information message
- `log_success()` - Success message
- `log_warning()` - Warning message
- `log_error()` - Error message
- `log_debug()` - Debug message (requires DEBUG=1)
- `echo_color()` - Echo with color

### Utilities
- `version_compare()` - Compare version strings
- `make_temp_file()` - Create temporary file
- `make_temp_dir()` - Create temporary directory
- `download_file()` - Download file (curl/wget)
- `extract_archive()` - Extract various archive formats
- `setup_cleanup()` - Setup cleanup function on exit

## Best Practices

1. **Always source the compatibility layer at the beginning:**
   ```bash
   source "$(dirname "${BASH_SOURCE[0]}")/utils/platform_compat.sh"
   ```

2. **Use feature detection instead of OS detection when possible:**
   ```bash
   # Good
   if command_exists cmake; then
       # Use cmake
   fi
   
   # Less preferred
   if [[ $(detect_os) == "linux" ]]; then
       # Assume cmake is available
   fi
   ```

3. **Use the logging functions for consistent output:**
   ```bash
   log_info "Starting build..."
   log_success "Build completed!"
   log_error "Build failed!"
   ```

4. **Handle paths carefully for Windows compatibility:**
   ```bash
   # Convert paths when passing to Windows programs
   NATIVE_PATH=$(to_native_path "$UNIX_PATH")
   ```

5. **Use the provided temp file/directory functions:**
   ```bash
   TEMP_DIR=$(make_temp_dir "build")
   # ... use temp dir ...
   remove_directory "$TEMP_DIR"
   ```

## Testing

To test the platform compatibility layer:

```bash
./platform_compat.sh
```

This will run a series of tests and display the results.

## Compatibility

- Bash 3.0+ (for macOS compatibility)
- Linux (all major distributions)
- macOS (10.10+)
- Windows (WSL, MSYS2, Cygwin, Git Bash)
- FreeBSD

## Common Issues and Solutions

### Issue: Colors not working
**Solution:** The library automatically detects color support. If colors aren't working, check:
- Terminal type: `echo $TERM`
- Force colors: `export TERM=xterm-256color`

### Issue: Command not found
**Solution:** Use `command_exists` to check before using:
```bash
if command_exists git; then
    GIT_PATH=$(find_executable git)
fi
```

### Issue: Path issues on Windows
**Solution:** Always use path conversion functions:
```bash
NATIVE_PATH=$(to_native_path "$PATH")
UNIX_PATH=$(to_unix_path "$PATH")
```

### Issue: Script fails on macOS
**Solution:** Ensure you're not using GNU-specific features. The library provides portable alternatives.

## Contributing

When adding new functions to `platform_compat.sh`:

1. Test on multiple platforms (Linux, macOS, Windows)
2. Provide fallbacks for missing commands
3. Document the function with examples
4. Add to this guide

## Examples

See `example_integration.sh` for a complete example of how to integrate the platform compatibility layer with an existing script.