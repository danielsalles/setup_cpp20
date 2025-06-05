#!/usr/bin/env bash
# Example script showing how to integrate platform_compat.sh with existing scripts

# Source the platform compatibility layer
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform_compat.sh"

# Example: Updating an existing script to use platform_compat.sh
# Before:
#   readonly OS_TYPE="$(uname -s)"
#   readonly ARCH_TYPE="$(uname -m)"
# After:
readonly OS_TYPE="$(detect_os)"
readonly ARCH_TYPE="$(detect_architecture)"

# Example: Cross-platform CPU core detection
# Before:
#   if [[ "$OS_TYPE" == "Darwin" ]]; then
#       JOBS=$(sysctl -n hw.ncpu)
#   else
#       JOBS=$(nproc 2>/dev/null || echo 1)
#   fi
# After:
JOBS=$(get_cpu_cores)

# Example: Path handling
# Before:
#   BUILD_DIR="${PROJECT_ROOT}/build"
# After:
BUILD_DIR=$(normalize_path "${PROJECT_ROOT}/build")

# Example: Tool detection
# Before:
#   if command -v cmake >/dev/null 2>&1; then
#       CMAKE_BINARY=cmake
#   fi
# After:
if command_exists cmake; then
    CMAKE_BINARY=$(find_executable cmake)
fi

# Example: Color support detection
# Before: Hardcoded colors
# After:
if supports_color; then
    # Colors are already set up by platform_compat.sh
    echo -e "${COLOR_GREEN}✅ Color support detected!${COLOR_RESET}"
else
    echo "Color support not available"
fi

# Example: Cross-platform temp file
# Before:
#   TEMP_FILE="/tmp/build_log_$$"
# After:
TEMP_FILE=$(make_temp_file "build_log")

# Example: Download with fallback
# Before:
#   curl -fsSL "https://example.com/file" -o output.txt
# After:
download_file "https://example.com/file" "output.txt"

echo ""
echo "Integration Examples Summary:"
echo "============================"
echo "OS Type: ${OS_TYPE}"
echo "Architecture: ${ARCH_TYPE}"
echo "CPU Cores: ${JOBS}"
echo "Build Directory: ${BUILD_DIR}"
echo "CMake Path: ${CMAKE_BINARY:-not found}"
echo "Temp File: ${TEMP_FILE}"

# Cleanup
[[ -f "${TEMP_FILE}" ]] && rm -f "${TEMP_FILE}"