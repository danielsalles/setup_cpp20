#!/usr/bin/env bash
# platform_compat.sh - Cross-platform compatibility layer for bash scripts
# This library provides functions for consistent behavior across Linux, macOS, and Windows (WSL/MSYS2/Cygwin)
# Compatible with bash 3.0+ for maximum portability

# Prevent multiple inclusion
if [[ -n "${PLATFORM_COMPAT_LOADED:-}" ]]; then
    return 0
fi
PLATFORM_COMPAT_LOADED=1

# ==========================================
# Platform Detection
# ==========================================

# Detect the operating system
detect_os() {
    local os_type=""
    local kernel=$(uname -s 2>/dev/null || echo "Unknown")
    
    case "${kernel}" in
        Linux*)
            if [[ -f /etc/os-release ]]; then
                os_type="linux"
            elif [[ -f /etc/redhat-release ]]; then
                os_type="linux"
            elif [[ -f /etc/debian_version ]]; then
                os_type="linux"
            else
                os_type="linux"
            fi
            ;;
        Darwin*)
            os_type="macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            os_type="windows"
            ;;
        FreeBSD*)
            os_type="freebsd"
            ;;
        *)
            os_type="unknown"
            ;;
    esac
    
    echo "${os_type}"
}

# Detect the specific Linux distribution
detect_linux_distro() {
    local distro=""
    
    if [[ -f /etc/os-release ]]; then
        # Modern way
        distro=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
    elif [[ -f /etc/redhat-release ]]; then
        distro="rhel"
    elif [[ -f /etc/debian_version ]]; then
        distro="debian"
    elif [[ -f /etc/SuSE-release ]]; then
        distro="suse"
    elif [[ -f /etc/arch-release ]]; then
        distro="arch"
    else
        distro="unknown"
    fi
    
    echo "${distro}"
}

# Detect Windows subsystem type
detect_windows_subsystem() {
    local subsystem=""
    local kernel=$(uname -s 2>/dev/null || echo "Unknown")
    
    case "${kernel}" in
        CYGWIN*)
            subsystem="cygwin"
            ;;
        MINGW32*)
            subsystem="mingw32"
            ;;
        MINGW64*)
            subsystem="mingw64"
            ;;
        MSYS*)
            subsystem="msys2"
            ;;
        *)
            # Check for WSL
            if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
                subsystem="wsl"
            else
                subsystem="unknown"
            fi
            ;;
    esac
    
    echo "${subsystem}"
}

# Get CPU architecture
detect_architecture() {
    local arch=$(uname -m 2>/dev/null || echo "unknown")
    
    case "${arch}" in
        x86_64|amd64)
            echo "x64"
            ;;
        i*86)
            echo "x86"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armv7)
            echo "arm"
            ;;
        *)
            echo "${arch}"
            ;;
    esac
}

# ==========================================
# Path Handling
# ==========================================

# Convert path to native format for the current platform
to_native_path() {
    local path="$1"
    local os_type=$(detect_os)
    
    if [[ "${os_type}" == "windows" ]]; then
        # Convert forward slashes to backslashes for Windows
        if command -v cygpath >/dev/null 2>&1; then
            cygpath -w "${path}" 2>/dev/null || echo "${path//\//\\}"
        else
            echo "${path//\//\\}"
        fi
    else
        # Unix-like systems use forward slashes
        echo "${path}"
    fi
}

# Convert path to Unix format (forward slashes)
to_unix_path() {
    local path="$1"
    local os_type=$(detect_os)
    
    if [[ "${os_type}" == "windows" ]]; then
        if command -v cygpath >/dev/null 2>&1; then
            cygpath -u "${path}" 2>/dev/null || echo "${path//\\//}"
        else
            echo "${path//\\//}"
        fi
    else
        echo "${path}"
    fi
}

# Get absolute path (cross-platform)
get_absolute_path() {
    local path="$1"
    local abs_path=""
    
    if [[ -d "${path}" ]]; then
        # Directory
        abs_path=$(cd "${path}" 2>/dev/null && pwd -P)
    elif [[ -f "${path}" ]]; then
        # File
        local dir=$(dirname "${path}")
        local file=$(basename "${path}")
        abs_path=$(cd "${dir}" 2>/dev/null && echo "$(pwd -P)/${file}")
    else
        # Path doesn't exist, try to resolve parent
        local dir=$(dirname "${path}")
        local base=$(basename "${path}")
        if [[ -d "${dir}" ]]; then
            abs_path=$(cd "${dir}" 2>/dev/null && echo "$(pwd -P)/${base}")
        else
            abs_path="${path}"
        fi
    fi
    
    echo "${abs_path}"
}

# Normalize path separators for the current platform
normalize_path() {
    local path="$1"
    local os_type=$(detect_os)
    
    if [[ "${os_type}" == "windows" ]]; then
        # Windows: ensure consistent separators
        echo "${path//\//\\}" | sed 's/\\\+/\\/g'
    else
        # Unix: ensure forward slashes
        echo "${path//\\//}" | sed 's/\/\+/\//g'
    fi
}

# ==========================================
# Tool Detection
# ==========================================

# Find executable in PATH (cross-platform which/where)
find_executable() {
    local exe="$1"
    
    # Try command -v first (most portable)
    if command -v "${exe}" >/dev/null 2>&1; then
        command -v "${exe}"
        return 0
    fi
    
    # Try which (Unix-like)
    if command -v which >/dev/null 2>&1; then
        which "${exe}" 2>/dev/null && return 0
    fi
    
    # Try where (Windows)
    if command -v where >/dev/null 2>&1; then
        where "${exe}" 2>/dev/null | head -n1 && return 0
    fi
    
    # Manual PATH search
    local IFS=:
    for dir in ${PATH}; do
        if [[ -x "${dir}/${exe}" ]]; then
            echo "${dir}/${exe}"
            return 0
        fi
    done
    
    return 1
}

# Check if command exists
command_exists() {
    local cmd="$1"
    find_executable "${cmd}" >/dev/null 2>&1
}

# Get command version (tries various version flags)
get_command_version() {
    local cmd="$1"
    local version=""
    
    if ! command_exists "${cmd}"; then
        return 1
    fi
    
    # Try common version flags
    for flag in "--version" "-version" "-v" "-V" "version"; do
        version=$("${cmd}" ${flag} 2>&1 | head -n1)
        if [[ $? -eq 0 ]] && [[ -n "${version}" ]]; then
            echo "${version}"
            return 0
        fi
    done
    
    return 1
}

# ==========================================
# Process Management
# ==========================================

# Get number of CPU cores (cross-platform)
get_cpu_cores() {
    local cores=1
    local os_type=$(detect_os)
    
    case "${os_type}" in
        linux|freebsd)
            if [[ -f /proc/cpuinfo ]]; then
                cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
            else
                cores=$(nproc 2>/dev/null || echo 1)
            fi
            ;;
        macos)
            cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
            ;;
        windows)
            cores=${NUMBER_OF_PROCESSORS:-1}
            ;;
        *)
            cores=1
            ;;
    esac
    
    echo "${cores}"
}

# Get available memory in MB (cross-platform)
get_available_memory() {
    local memory=0
    local os_type=$(detect_os)
    
    case "${os_type}" in
        linux)
            if [[ -f /proc/meminfo ]]; then
                memory=$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
            fi
            ;;
        macos)
            # Get free memory pages and page size
            local pages=$(vm_stat | awk '/Pages free:/ {print $3}' | tr -d '.')
            local page_size=$(pagesize 2>/dev/null || echo 4096)
            memory=$((pages * page_size / 1024 / 1024))
            ;;
        windows)
            # Use wmic if available
            if command_exists wmic; then
                memory=$(wmic OS get FreePhysicalMemory /value | grep -o '[0-9]*' | head -1)
                memory=$((memory / 1024))
            fi
            ;;
    esac
    
    echo "${memory}"
}

# ==========================================
# Terminal/Console Handling
# ==========================================

# Check if running in a terminal
is_terminal() {
    [[ -t 1 ]] && [[ -t 2 ]]
}

# Check if terminal supports colors
supports_color() {
    # Check if stdout is a terminal
    if ! is_terminal; then
        return 1
    fi
    
    # Check TERM variable
    case "${TERM}" in
        *color*|xterm*|rxvt*|screen*|tmux*|alacritty*|kitty*)
            return 0
            ;;
    esac
    
    # Check if tput is available
    if command_exists tput; then
        local colors=$(tput colors 2>/dev/null || echo 0)
        [[ ${colors} -ge 8 ]] && return 0
    fi
    
    # Check for Windows terminal
    if [[ -n "${WT_SESSION}" ]] || [[ -n "${TERMINAL_EMULATOR}" ]]; then
        return 0
    fi
    
    return 1
}

# Get terminal width
get_terminal_width() {
    local width=80  # Default
    
    if command_exists tput; then
        width=$(tput cols 2>/dev/null || echo 80)
    elif command_exists stty; then
        width=$(stty size 2>/dev/null | cut -d' ' -f2 || echo 80)
    fi
    
    echo "${width}"
}

# ==========================================
# File System Operations
# ==========================================

# Create directory with parents (cross-platform mkdir -p)
make_directory() {
    local dir="$1"
    
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}" 2>/dev/null || {
            # Fallback for systems without -p
            local parent=$(dirname "${dir}")
            [[ ! -d "${parent}" ]] && make_directory "${parent}"
            mkdir "${dir}" 2>/dev/null
        }
    fi
}

# Remove directory recursively (cross-platform rm -rf)
remove_directory() {
    local dir="$1"
    
    if [[ -d "${dir}" ]]; then
        rm -rf "${dir}" 2>/dev/null || {
            # Fallback for Windows
            if [[ $(detect_os) == "windows" ]]; then
                rmdir /s /q "$(to_native_path "${dir}")" 2>/dev/null
            fi
        }
    fi
}

# Copy file/directory (cross-platform cp -r)
copy_recursive() {
    local src="$1"
    local dst="$2"
    
    if command_exists cp; then
        cp -r "${src}" "${dst}" 2>/dev/null
    elif [[ $(detect_os) == "windows" ]]; then
        if [[ -d "${src}" ]]; then
            xcopy "$(to_native_path "${src}")" "$(to_native_path "${dst}")" /E /I /Q /Y 2>/dev/null
        else
            copy "$(to_native_path "${src}")" "$(to_native_path "${dst}")" /Y 2>/dev/null
        fi
    fi
}

# Get file modification time in seconds since epoch
get_file_mtime() {
    local file="$1"
    local mtime=0
    local os_type=$(detect_os)
    
    if [[ ! -e "${file}" ]]; then
        echo "0"
        return 1
    fi
    
    case "${os_type}" in
        linux|freebsd)
            mtime=$(stat -c %Y "${file}" 2>/dev/null || echo 0)
            ;;
        macos)
            mtime=$(stat -f %m "${file}" 2>/dev/null || echo 0)
            ;;
        windows)
            # Try GNU stat first
            mtime=$(stat -c %Y "${file}" 2>/dev/null || echo 0)
            ;;
    esac
    
    echo "${mtime}"
}

# ==========================================
# Environment Variables
# ==========================================

# Export variable (handles Windows SET vs export)
export_var() {
    local name="$1"
    local value="$2"
    
    export "${name}=${value}"
    
    # For Windows cmd compatibility
    if [[ $(detect_os) == "windows" ]] && [[ -n "${COMSPEC}" ]]; then
        set "${name}=${value}" 2>/dev/null || true
    fi
}

# Append to PATH (cross-platform)
append_to_path() {
    local dir="$1"
    local abs_dir=$(get_absolute_path "${dir}")
    
    if [[ -d "${abs_dir}" ]]; then
        case ":${PATH}:" in
            *:"${abs_dir}":*)
                # Already in PATH
                ;;
            *)
                export_var PATH "${PATH}:${abs_dir}"
                ;;
        esac
    fi
}

# Prepend to PATH (cross-platform)
prepend_to_path() {
    local dir="$1"
    local abs_dir=$(get_absolute_path "${dir}")
    
    if [[ -d "${abs_dir}" ]]; then
        case ":${PATH}:" in
            *:"${abs_dir}":*)
                # Already in PATH
                ;;
            *)
                export_var PATH "${abs_dir}:${PATH}"
                ;;
        esac
    fi
}

# ==========================================
# Shell Detection
# ==========================================

# Detect current shell
detect_shell() {
    local shell_name=""
    
    # Try $SHELL first
    if [[ -n "${SHELL}" ]]; then
        shell_name=$(basename "${SHELL}")
    # Try parent process
    elif [[ -f /proc/$$/comm ]]; then
        shell_name=$(cat /proc/$$/comm)
    # Try ps command
    elif command_exists ps; then
        shell_name=$(ps -p $$ -o comm= 2>/dev/null | tail -1 | sed 's/^-//')
    fi
    
    # Normalize shell name
    case "${shell_name}" in
        *bash*)
            echo "bash"
            ;;
        *zsh*)
            echo "zsh"
            ;;
        *fish*)
            echo "fish"
            ;;
        *ksh*)
            echo "ksh"
            ;;
        *sh*)
            echo "sh"
            ;;
        *)
            echo "${shell_name:-unknown}"
            ;;
    esac
}

# Get shell configuration file
get_shell_config() {
    local shell_type=$(detect_shell)
    local config_file=""
    
    case "${shell_type}" in
        bash)
            if [[ -f "${HOME}/.bashrc" ]]; then
                config_file="${HOME}/.bashrc"
            elif [[ -f "${HOME}/.bash_profile" ]]; then
                config_file="${HOME}/.bash_profile"
            fi
            ;;
        zsh)
            if [[ -f "${HOME}/.zshrc" ]]; then
                config_file="${HOME}/.zshrc"
            elif [[ -f "${HOME}/.zprofile" ]]; then
                config_file="${HOME}/.zprofile"
            fi
            ;;
        fish)
            config_file="${HOME}/.config/fish/config.fish"
            ;;
        ksh)
            config_file="${HOME}/.kshrc"
            ;;
        *)
            # Default to .profile
            config_file="${HOME}/.profile"
            ;;
    esac
    
    echo "${config_file}"
}

# ==========================================
# Logging Functions
# ==========================================

# ANSI color codes (if supported)
setup_colors() {
    if supports_color; then
        export COLOR_RESET='\033[0m'
        export COLOR_RED='\033[0;31m'
        export COLOR_GREEN='\033[0;32m'
        export COLOR_YELLOW='\033[0;33m'
        export COLOR_BLUE='\033[0;34m'
        export COLOR_MAGENTA='\033[0;35m'
        export COLOR_CYAN='\033[0;36m'
        export COLOR_WHITE='\033[0;37m'
        export COLOR_BOLD='\033[1m'
    else
        export COLOR_RESET=''
        export COLOR_RED=''
        export COLOR_GREEN=''
        export COLOR_YELLOW=''
        export COLOR_BLUE=''
        export COLOR_MAGENTA=''
        export COLOR_CYAN=''
        export COLOR_WHITE=''
        export COLOR_BOLD=''
    fi
}

# Initialize colors
setup_colors

# Cross-platform echo with color support
echo_color() {
    local color="$1"
    shift
    local message="$*"
    
    if supports_color; then
        echo -e "${color}${message}${COLOR_RESET}"
    else
        echo "${message}"
    fi
}

# Logging functions
log_info() {
    echo_color "${COLOR_BLUE}" "[INFO] $*"
}

log_success() {
    echo_color "${COLOR_GREEN}" "[SUCCESS] $*"
}

log_warning() {
    echo_color "${COLOR_YELLOW}" "[WARNING] $*"
}

log_error() {
    echo_color "${COLOR_RED}" "[ERROR] $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo_color "${COLOR_CYAN}" "[DEBUG] $*" >&2
    fi
}

# ==========================================
# Utility Functions
# ==========================================

# Compare versions (returns 0 if version1 >= version2)
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Remove non-numeric prefixes
    version1=$(echo "${version1}" | sed 's/^[^0-9]*//')
    version2=$(echo "${version2}" | sed 's/^[^0-9]*//')
    
    # Compare using sort -V if available
    if command_exists sort && sort --help 2>&1 | grep -q -- '-V'; then
        local highest=$(printf "%s\n%s" "${version1}" "${version2}" | sort -V | tail -n1)
        [[ "${highest}" == "${version1}" ]]
    else
        # Fallback to simple comparison
        local IFS=.
        local i ver1=($version1) ver2=($version2)
        
        # Fill empty fields in ver1 with zeros
        for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
            ver1[i]=0
        done
        
        for ((i=0; i<${#ver1[@]}; i++)); do
            if [[ -z ${ver2[i]} ]]; then
                ver2[i]=0
            fi
            if ((10#${ver1[i]} > 10#${ver2[i]})); then
                return 0
            fi
            if ((10#${ver1[i]} < 10#${ver2[i]})); then
                return 1
            fi
        done
        
        return 0
    fi
}

# Generate temporary file (cross-platform)
make_temp_file() {
    local prefix="${1:-tmp}"
    local temp_file=""
    
    if command_exists mktemp; then
        temp_file=$(mktemp -t "${prefix}.XXXXXX" 2>/dev/null)
    else
        # Fallback
        temp_file="/tmp/${prefix}.$$.$RANDOM"
        touch "${temp_file}"
    fi
    
    echo "${temp_file}"
}

# Generate temporary directory (cross-platform)
make_temp_dir() {
    local prefix="${1:-tmpdir}"
    local temp_dir=""
    
    if command_exists mktemp; then
        temp_dir=$(mktemp -d -t "${prefix}.XXXXXX" 2>/dev/null)
    else
        # Fallback
        temp_dir="/tmp/${prefix}.$$.$RANDOM"
        make_directory "${temp_dir}"
    fi
    
    echo "${temp_dir}"
}

# URL download (tries curl, then wget)
download_file() {
    local url="$1"
    local output="$2"
    
    if command_exists curl; then
        curl -fsSL "${url}" -o "${output}"
    elif command_exists wget; then
        wget -q -O "${output}" "${url}"
    else
        log_error "Neither curl nor wget found. Cannot download files."
        return 1
    fi
}

# Extract archive (handles .tar.gz, .zip, etc.)
extract_archive() {
    local archive="$1"
    local dest_dir="${2:-.}"
    
    case "${archive}" in
        *.tar.gz|*.tgz)
            tar -xzf "${archive}" -C "${dest_dir}"
            ;;
        *.tar.bz2|*.tbz2)
            tar -xjf "${archive}" -C "${dest_dir}"
            ;;
        *.tar.xz|*.txz)
            tar -xJf "${archive}" -C "${dest_dir}"
            ;;
        *.tar)
            tar -xf "${archive}" -C "${dest_dir}"
            ;;
        *.zip)
            if command_exists unzip; then
                unzip -q "${archive}" -d "${dest_dir}"
            else
                log_error "unzip not found. Cannot extract ${archive}"
                return 1
            fi
            ;;
        *.7z)
            if command_exists 7z; then
                7z x -o"${dest_dir}" "${archive}" >/dev/null
            else
                log_error "7z not found. Cannot extract ${archive}"
                return 1
            fi
            ;;
        *)
            log_error "Unknown archive format: ${archive}"
            return 1
            ;;
    esac
}

# ==========================================
# Signal Handling
# ==========================================

# Setup cleanup on exit
setup_cleanup() {
    local cleanup_function="$1"
    
    # Trap multiple signals
    trap "${cleanup_function}" EXIT INT TERM HUP
}

# ==========================================
# Testing Functions
# ==========================================

# Run platform compatibility tests
test_platform_compat() {
    echo "Testing Platform Compatibility Layer..."
    echo "======================================="
    
    echo "OS Detection: $(detect_os)"
    if [[ $(detect_os) == "linux" ]]; then
        echo "Linux Distribution: $(detect_linux_distro)"
    elif [[ $(detect_os) == "windows" ]]; then
        echo "Windows Subsystem: $(detect_windows_subsystem)"
    fi
    echo "Architecture: $(detect_architecture)"
    echo "CPU Cores: $(get_cpu_cores)"
    echo "Available Memory: $(get_available_memory) MB"
    echo "Current Shell: $(detect_shell)"
    echo "Shell Config: $(get_shell_config)"
    echo "Terminal Width: $(get_terminal_width)"
    echo "Supports Color: $(supports_color && echo "Yes" || echo "No")"
    
    echo ""
    echo "Testing logging functions..."
    log_info "This is an info message"
    log_success "This is a success message"
    log_warning "This is a warning message"
    log_error "This is an error message"
    DEBUG=1 log_debug "This is a debug message"
    
    echo ""
    echo "Testing path functions..."
    local test_path="/usr/local/bin/test"
    echo "Unix path: ${test_path}"
    echo "Native path: $(to_native_path "${test_path}")"
    echo "Absolute path of .: $(get_absolute_path ".")"
    
    echo ""
    echo "Testing tool detection..."
    echo "bash exists: $(command_exists bash && echo "Yes" || echo "No")"
    echo "bash path: $(find_executable bash || echo "Not found")"
    if command_exists bash; then
        echo "bash version: $(get_command_version bash | head -1)"
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_platform_compat
fi