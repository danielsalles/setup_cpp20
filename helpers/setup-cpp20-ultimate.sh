#!/bin/bash

# 🚀 ULTIMATE C++20 SETUP SCRIPT
# Complete modern C++20 development environment for macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/danielsalles/main/helpers/setup-cpp20-ultimate.sh | bash

set -euo pipefail

# 🎨 Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# 📊 Configuration
readonly SCRIPT_VERSION="2.0.0"
readonly VCPKG_DIR="$HOME/.vcpkg"

# 🎯 Helper functions
log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}" >&2; }
log_header() { echo -e "${PURPLE}${BOLD}🚀 $*${NC}"; }
log_step() { echo -e "${CYAN}📋 $*${NC}"; }

# 🔍 Robust System detection
detect_system() {
    local os_type=""
    local distro=""
    local version=""
    local arch=""
    
    # Detect architecture
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l) arch="arm" ;;
        *) arch="unknown" ;;
    esac
    
    # Detect operating system
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os_type="macos"
        version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
        echo "${os_type}-${arch}-${version}"
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$(uname)" == "Linux" ]]; then
        os_type="linux"
        
        # Try lsb_release first (most reliable)
        if command -v lsb_release >/dev/null 2>&1; then
            distro=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
            version=$(lsb_release -sr 2>/dev/null)
        elif [[ -f /etc/os-release ]]; then
            # Fallback to /etc/os-release
            source /etc/os-release
            distro=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
            version="$VERSION_ID"
        elif [[ -f /etc/redhat-release ]]; then
            # Fallback for older RHEL systems
            if grep -qi "centos" /etc/redhat-release; then
                distro="centos"
            elif grep -qi "fedora" /etc/redhat-release; then
                distro="fedora"
            elif grep -qi "red hat" /etc/redhat-release; then
                distro="rhel"
            else
                distro="redhat"
            fi
            version=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
        elif [[ -f /etc/debian_version ]]; then
            # Fallback for Debian-based systems
            distro="debian"
            version=$(cat /etc/debian_version)
        else
            # Generic Linux fallback
            distro="unknown"
            version="unknown"
        fi
        
        echo "${os_type}-${distro}-${arch}-${version}"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows-${arch}"
    else
        echo "unknown-${arch}"
    fi
}

# 📊 Parse system information
get_system_info() {
    local system_string
    system_string=$(detect_system)
    
    # Create global variables for system information
    SYSTEM_OS=""
    SYSTEM_DISTRO=""
    SYSTEM_ARCH=""
    SYSTEM_VERSION=""
    
    IFS='-' read -ra PARTS <<< "$system_string"
    
    case "${#PARTS[@]}" in
        3) # macOS or Windows: os-arch-version or windows-arch
            SYSTEM_OS="${PARTS[0]}"
            SYSTEM_ARCH="${PARTS[1]}"
            SYSTEM_VERSION="${PARTS[2]:-unknown}"
            SYSTEM_DISTRO="$SYSTEM_OS"
            ;;
        4) # Linux: linux-distro-arch-version
            SYSTEM_OS="${PARTS[0]}"
            SYSTEM_DISTRO="${PARTS[1]}"
            SYSTEM_ARCH="${PARTS[2]}"
            SYSTEM_VERSION="${PARTS[3]}"
            ;;
        2) # Fallback: os-arch
            SYSTEM_OS="${PARTS[0]}"
            SYSTEM_ARCH="${PARTS[1]}"
            SYSTEM_DISTRO="$SYSTEM_OS"
            SYSTEM_VERSION="unknown"
            ;;
        *) # Unknown format
            SYSTEM_OS="unknown"
            SYSTEM_DISTRO="unknown"
            SYSTEM_ARCH="unknown"
            SYSTEM_VERSION="unknown"
            ;;
    esac
}

# 🎨 Show banner
show_banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║               🚀 ULTIMATE C++20 SETUP SCRIPT                 ║
║                                                              ║
║  Essential modern development environment configuration      ║
║  • Package manager (vcpkg)                                   ║
║  • Development tools (CMake, Ninja, Clang)                   ║
║  • Essential aliases and utilities                           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}Version: ${SCRIPT_VERSION}${NC}"
    
    get_system_info
    echo -e "${CYAN}System: ${SYSTEM_OS} (${SYSTEM_DISTRO}) ${SYSTEM_ARCH} v${SYSTEM_VERSION}${NC}"
    echo
}

# 🔍 Check prerequisites robustly
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    local errors=0
    
    # Get system information
    get_system_info
    
    # Check bash version (more lenient for macOS)
    local bash_version
    bash_version=$(bash --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local min_bash_version="3.2"
    local recommended_bash_version="4.0"
    
    if [[ -n "$bash_version" ]]; then
        if [[ $(echo "$bash_version >= $min_bash_version" | bc -l 2>/dev/null || echo 0) -eq 0 ]]; then
            log_error "Bash version $min_bash_version+ required, found $bash_version"
            ((errors++))
        elif [[ $(echo "$bash_version >= $recommended_bash_version" | bc -l 2>/dev/null || echo 0) -eq 0 ]]; then
            log_warning "Bash version: $bash_version (recommend $recommended_bash_version+ for best compatibility)"
            if [[ "$SYSTEM_OS" == "macos" ]]; then
                log_info "Install modern bash with: brew install bash"
            fi
        else
            log_success "Bash version: $bash_version"
        fi
    else
        log_error "Could not determine bash version"
        ((errors++))
    fi
    
    # Check required tools with minimum versions
    local tools_status=()
    
    # Check curl
    if command -v curl >/dev/null 2>&1; then
        local curl_version
        curl_version=$(curl --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_success "curl: $curl_version"
        tools_status+=("curl:ok")
    else
        log_error "curl: Not found"
        tools_status+=("curl:missing")
        ((errors++))
    fi
    
    # Check git
    if command -v git >/dev/null 2>&1; then
        local git_version
        git_version=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        local min_git_version="2.20.0"
        if [[ -n "$git_version" ]] && [[ $(printf '%s\n' "$min_git_version" "$git_version" | sort -V | head -n1) == "$min_git_version" ]]; then
            log_success "git: $git_version"
            tools_status+=("git:ok")
        else
            log_warning "git: $git_version (minimum $min_git_version recommended)"
            tools_status+=("git:old")
        fi
    else
        log_error "git: Not found"
        tools_status+=("git:missing")
        ((errors++))
    fi
    
    # Platform-specific checks
    case "$SYSTEM_OS" in
        "macos")
            check_macos_prerequisites
            ;;
        "linux")
            check_linux_prerequisites "$SYSTEM_DISTRO"
            ;;
        "windows")
            log_warning "Windows support is experimental"
            ;;
        *)
            log_warning "Unknown platform: $SYSTEM_OS"
            ;;
    esac
    
    # Provide installation guidance for missing tools
    if [[ $errors -gt 0 ]]; then
        log_header "Installation Guidance"
        provide_installation_guidance
        exit 1
    fi
    
    log_success "All prerequisites check passed"
}

# 🍎 macOS-specific prerequisite checks
check_macos_prerequisites() {
    log_step "Checking macOS-specific prerequisites..."
    
    # Check macOS version
    local macos_version="$SYSTEM_VERSION"
    log_info "macOS version: $macos_version"
    
    # Check if version is compatible (macOS 11+)
    local major_version
    major_version=$(echo "$macos_version" | cut -d. -f1)
    if [[ $major_version -lt 11 ]]; then
        log_error "macOS 11.0 or later required, found $macos_version"
        ((errors++))
    fi
    
    # Check for Xcode Command Line Tools
    if xcode-select -p >/dev/null 2>&1; then
        local xcode_path
        xcode_path=$(xcode-select -p)
        log_success "Xcode Command Line Tools: $xcode_path"
    else
        log_error "Xcode Command Line Tools not found"
        log_info "Run: xcode-select --install"
        ((errors++))
    fi
    
    # Check for Homebrew (recommended but not required)
    if command -v brew >/dev/null 2>&1; then
        local brew_version
        brew_version=$(brew --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        log_success "Homebrew: $brew_version (recommended)"
    else
        log_warning "Homebrew not found (recommended for easier tool installation)"
        log_info "Install from: https://brew.sh"
    fi
}

# 🐧 Linux-specific prerequisite checks
check_linux_prerequisites() {
    local distro="$1"
    log_step "Checking Linux-specific prerequisites ($distro)..."
    
    # Check for build essentials
    case "$distro" in
        "ubuntu"|"debian")
            if ! dpkg -l build-essential >/dev/null 2>&1; then
                log_error "build-essential package not found"
                log_info "Install with: sudo apt-get install build-essential"
                ((errors++))
            else
                log_success "build-essential: installed"
            fi
            ;;
        "centos"|"rhel"|"fedora")
            if ! rpm -q gcc gcc-c++ make >/dev/null 2>&1; then
                log_error "Development tools not found"
                log_info "Install with: sudo yum groupinstall 'Development Tools'"
                ((errors++))
            else
                log_success "Development tools: installed"
            fi
            ;;
        "arch")
            if ! pacman -Q base-devel >/dev/null 2>&1; then
                log_error "base-devel package group not found"
                log_info "Install with: sudo pacman -S base-devel"
                ((errors++))
            else
                log_success "base-devel: installed"
            fi
            ;;
        *)
            log_warning "Unknown Linux distribution: $distro"
            log_info "Please ensure development tools (gcc, g++, make) are installed"
            ;;
    esac
    
    # Check for package manager
    local pkg_manager=""
    if command -v apt-get >/dev/null 2>&1; then
        pkg_manager="apt-get"
    elif command -v yum >/dev/null 2>&1; then
        pkg_manager="yum"
    elif command -v dnf >/dev/null 2>&1; then
        pkg_manager="dnf"
    elif command -v pacman >/dev/null 2>&1; then
        pkg_manager="pacman"
    elif command -v zypper >/dev/null 2>&1; then
        pkg_manager="zypper"
    fi
    
    if [[ -n "$pkg_manager" ]]; then
        log_success "Package manager: $pkg_manager"
    else
        log_warning "No recognized package manager found"
        ((errors++))
    fi
}

# 📋 Provide installation guidance for missing tools
provide_installation_guidance() {
    case "$SYSTEM_OS" in
        "macos")
            log_info "For macOS:"
            log_info "1. Install Xcode Command Line Tools: xcode-select --install"
            log_info "2. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            log_info "3. Install missing tools: brew install curl git"
            ;;
        "linux")
            case "$SYSTEM_DISTRO" in
                "ubuntu"|"debian")
                    log_info "For $SYSTEM_DISTRO:"
                    log_info "sudo apt-get update"
                    log_info "sudo apt-get install -y curl git build-essential"
                    ;;
                "centos"|"rhel"|"fedora")
                    log_info "For $SYSTEM_DISTRO:"
                    log_info "sudo yum install -y curl git"
                    log_info "sudo yum groupinstall 'Development Tools'"
                    ;;
                "arch")
                    log_info "For Arch Linux:"
                    log_info "sudo pacman -S curl git base-devel"
                    ;;
                *)
                    log_info "Please install curl, git, and development tools for your distribution"
                    ;;
            esac
            ;;
        *)
            log_info "Please install curl and git for your platform"
            ;;
    esac
}

# 📦 Install package managers (Homebrew for macOS, native managers for Linux)
install_package_managers() {
    log_header "Setting up Package Managers"
    
    case "$SYSTEM_OS" in
        "macos")
            install_homebrew_macos
            ;;
        "linux")
            setup_linux_package_manager
            ;;
        *)
            log_warning "Package manager setup not implemented for $SYSTEM_OS"
            ;;
    esac
}

# 🍎 Install Homebrew for macOS
install_homebrew_macos() {
    log_step "Setting up Homebrew for macOS..."
    
    if command -v brew &>/dev/null; then
        log_info "Homebrew already installed: $(brew --version | head -n1)"
        log_step "Updating Homebrew..."
        brew update
    else
        log_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add to PATH for Apple Silicon
        if [[ "$SYSTEM_ARCH" == "arm64" ]]; then
            echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
            export PATH="/opt/homebrew/bin:$PATH"
        fi
    fi
    
    log_success "Homebrew ready"
}

# 🐧 Setup Linux package manager
setup_linux_package_manager() {
    log_step "Setting up package manager for $SYSTEM_DISTRO..."
    
    case "$SYSTEM_DISTRO" in
        "ubuntu"|"debian")
            log_step "Updating apt package lists..."
            sudo apt-get update
            log_success "apt package manager ready"
            ;;
        "centos"|"rhel"|"fedora")
            if command -v dnf &>/dev/null; then
                log_step "Updating dnf metadata..."
                sudo dnf makecache
                log_success "dnf package manager ready"
            elif command -v yum &>/dev/null; then
                log_step "Updating yum cache..."
                sudo yum makecache
                log_success "yum package manager ready"
            fi
            ;;
        "arch")
            log_step "Updating pacman database..."
            sudo pacman -Sy
            log_success "pacman package manager ready"
            ;;
        *)
            log_warning "Package manager setup not implemented for $SYSTEM_DISTRO"
            ;;
    esac
}

# 🔧 Install development tools across platforms
install_dev_tools() {
    log_header "Installing Development Tools"
    
    get_system_info
    
    case "$SYSTEM_OS" in
        "macos")
            install_tools_macos
            ;;
        "linux")
            install_tools_linux "$SYSTEM_DISTRO"
            ;;
        *)
            log_error "Tool installation not implemented for $SYSTEM_OS"
            exit 1
            ;;
    esac
    
    log_success "Development tools installation completed"
}

# 🍎 Install tools on macOS via Homebrew
install_tools_macos() {
    log_step "Installing macOS development tools via Homebrew..."
    
    local tools=(
        "cmake"          # Build system generator
        "ninja"          # Fast build system
        "pkg-config"     # Package configuration
        "llvm"           # Modern Clang with C++20
        "gcc"            # GCC compiler
        "git"            # Version control
        "jq"             # JSON processor
        "python3"        # Python 3
    )
    
    for tool in "${tools[@]}"; do
        install_tool_macos "$tool"
    done
}

# 🐧 Install tools on Linux via native package managers
install_tools_linux() {
    local distro="$1"
    log_step "Installing Linux development tools for $distro..."
    
    case "$distro" in
        "ubuntu"|"debian")
            install_tools_debian_ubuntu
            ;;
        "centos"|"rhel"|"fedora")
            install_tools_redhat_fedora
            ;;
        "arch")
            install_tools_arch
            ;;
        *)
            log_error "Tool installation not implemented for $distro"
            exit 1
            ;;
    esac
}

# 📦 Install single tool on macOS
install_tool_macos() {
    local tool="$1"
    
    if brew list "$tool" &>/dev/null 2>&1; then
        log_info "$tool already installed"
    else
        log_step "Installing $tool..."
        if brew install "$tool"; then
            log_success "$tool installed successfully"
        else
            log_error "Failed to install $tool"
            return 1
        fi
    fi
}

# 🐧 Install tools on Ubuntu/Debian
install_tools_debian_ubuntu() {
    local packages=(
        "cmake"              # Build system generator
        "ninja-build"        # Fast build system
        "pkg-config"         # Package configuration
        "clang"              # Modern Clang compiler
        "clang-tools"        # Clang tools
        "libc++-dev"         # libc++ standard library
        "libc++abi-dev"      # libc++abi
        "gcc"                # GCC compiler
        "g++"                # G++ compiler
        "git"                # Version control
        "jq"                 # JSON processor
        "python3"            # Python 3
        "python3-pip"        # Python package manager
        "curl"               # HTTP client
        "wget"               # File downloader
        "build-essential"    # Essential build tools
    )
    
    log_step "Installing packages via apt..."
    if sudo apt-get install -y "${packages[@]}"; then
        log_success "All packages installed successfully"
    else
        log_error "Some packages failed to install"
        return 1
    fi
    
    # Install latest CMake from Kitware APT repository if version is too old
    install_latest_cmake_ubuntu
}

# 🐧 Install tools on CentOS/RHEL/Fedora
install_tools_redhat_fedora() {
    local packages=(
        "cmake"              # Build system generator
        "ninja-build"        # Fast build system
        "pkgconfig"          # Package configuration
        "clang"              # Modern Clang compiler
        "clang-tools-extra"  # Clang tools
        "libcxx-devel"       # libc++ standard library
        "gcc"                # GCC compiler
        "gcc-c++"            # G++ compiler
        "git"                # Version control
        "jq"                 # JSON processor
        "python3"            # Python 3
        "python3-pip"        # Python package manager
        "curl"               # HTTP client
        "wget"               # File downloader
    )
    
    log_step "Installing packages..."
    local pkg_manager=""
    if command -v dnf &>/dev/null; then
        pkg_manager="dnf"
    elif command -v yum &>/dev/null; then
        pkg_manager="yum"
    else
        log_error "No package manager found (dnf/yum)"
        return 1
    fi
    
    if sudo "$pkg_manager" install -y "${packages[@]}"; then
        log_success "All packages installed successfully"
    else
        log_error "Some packages failed to install"
        return 1
    fi
}

# 🐧 Install tools on Arch Linux
install_tools_arch() {
    local packages=(
        "cmake"              # Build system generator
        "ninja"              # Fast build system
        "pkg-config"         # Package configuration
        "clang"              # Modern Clang compiler
        "libc++"             # libc++ standard library
        "gcc"                # GCC compiler
        "git"                # Version control
        "jq"                 # JSON processor
        "python"             # Python 3
        "python-pip"         # Python package manager
        "curl"               # HTTP client
        "wget"               # File downloader
        "base-devel"         # Essential build tools
    )
    
    log_step "Installing packages via pacman..."
    if sudo pacman -S --needed --noconfirm "${packages[@]}"; then
        log_success "All packages installed successfully"
    else
        log_error "Some packages failed to install"
        return 1
    fi
}

# 🔄 Install latest CMake on Ubuntu (if needed)
install_latest_cmake_ubuntu() {
    local cmake_version
    cmake_version=$(cmake --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local min_cmake_version="3.20"
    
    if [[ -n "$cmake_version" ]] && [[ $(printf '%s\n' "$min_cmake_version" "$cmake_version" | sort -V | head -n1) == "$min_cmake_version" ]]; then
        log_info "CMake version $cmake_version is sufficient"
        return 0
    fi
    
    log_step "Installing latest CMake from Kitware repository..."
    
    # Add Kitware APT repository
    if ! grep -q "apt.kitware.com" /etc/apt/sources.list.d/* 2>/dev/null; then
        wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | sudo apt-key add -
        
        local ubuntu_codename
        ubuntu_codename=$(lsb_release -cs 2>/dev/null || echo "focal")
        
        echo "deb https://apt.kitware.com/ubuntu/ $ubuntu_codename main" | sudo tee /etc/apt/sources.list.d/kitware.list
        sudo apt-get update
        sudo apt-get install -y cmake
        
        log_success "Latest CMake installed from Kitware repository"
    else
        log_info "Kitware repository already configured"
    fi
}

# 📚 Setup vcpkg package manager
setup_vcpkg() {
    log_header "Setting up vcpkg Package Manager"
    
    get_system_info
    
    # Set vcpkg directory based on system
    local vcpkg_dir="$HOME/.vcpkg"
    export VCPKG_ROOT="$vcpkg_dir"
    
    # Check if vcpkg already exists and is functional
    if [[ -d "$vcpkg_dir" ]] && [[ -x "$vcpkg_dir/vcpkg" ]]; then
        log_info "vcpkg already installed at $vcpkg_dir"
        if verify_vcpkg_installation "$vcpkg_dir"; then
            log_success "vcpkg is functional and ready"
            return 0
        else
            log_warning "vcpkg exists but is not functional, reinstalling..."
            rm -rf "$vcpkg_dir"
        fi
    fi
    
    # Install vcpkg from scratch
    install_vcpkg_fresh "$vcpkg_dir"
    
    # Configure vcpkg integration
    configure_vcpkg_integration "$vcpkg_dir"
    
    # Verify final installation
    if verify_vcpkg_installation "$vcpkg_dir"; then
        log_success "vcpkg installation completed successfully"
        
        # Run C++20 compilation verification
        verify_cpp20_compilation
        
        return 0
    else
        log_error "vcpkg installation failed"
        return 1
    fi
}

# 🔧 Install vcpkg from scratch
install_vcpkg_fresh() {
    local vcpkg_dir="$1"
    
    log_step "Installing vcpkg from scratch..."
    
    # Clone vcpkg repository
    log_step "Cloning vcpkg repository..."
    if ! git clone https://github.com/Microsoft/vcpkg.git "$vcpkg_dir"; then
        log_error "Failed to clone vcpkg repository"
        return 1
    fi
    
    cd "$vcpkg_dir" || {
        log_error "Failed to change to vcpkg directory"
        return 1
    }
    
    # Bootstrap vcpkg
    log_step "Bootstrapping vcpkg..."
    local bootstrap_script=""
    if [[ "$SYSTEM_OS" == "macos" ]] || [[ "$SYSTEM_OS" == "linux" ]]; then
        bootstrap_script="./bootstrap-vcpkg.sh"
    else
        log_error "Unsupported platform for vcpkg bootstrap: $SYSTEM_OS"
        return 1
    fi
    
    if ! $bootstrap_script; then
        log_error "vcpkg bootstrap failed"
        return 1
    fi
    
    log_success "vcpkg bootstrap completed"
    return 0
}

# ⚙️ Configure vcpkg integration
configure_vcpkg_integration() {
    local vcpkg_dir="$1"
    
    log_step "Configuring vcpkg integration..."
    
    cd "$vcpkg_dir" || {
        log_error "Failed to change to vcpkg directory"
        return 1
    }
    
    # Global integration
    log_step "Setting up global vcpkg integration..."
    if ./vcpkg integrate install; then
        log_success "vcpkg global integration configured"
    else
        log_warning "vcpkg global integration failed (may require admin privileges)"
    fi
    
    # Install common C++20 packages for testing
    log_step "Installing essential C++20 packages..."
    install_essential_vcpkg_packages "$vcpkg_dir"
    
    return 0
}

# 📦 Install essential vcpkg packages
install_essential_vcpkg_packages() {
    local vcpkg_dir="$1"
    
    local essential_packages=(
        "fmt"           # Modern formatting library
        "spdlog"        # Fast logging library
        "catch2"        # Modern C++ testing framework
        "nlohmann-json" # JSON library
    )
    
    log_step "Installing essential packages: ${essential_packages[*]}"
    
    cd "$vcpkg_dir" || return 1
    
    for package in "${essential_packages[@]}"; do
        log_step "Installing $package..."
        if ./vcpkg install "$package"; then
            log_success "$package installed successfully"
        else
            log_warning "Failed to install $package (continuing anyway)"
        fi
    done
    
    return 0
}

# ✅ Verify vcpkg installation
verify_vcpkg_installation() {
    local vcpkg_dir="$1"
    
    # Check if directory exists
    if [[ ! -d "$vcpkg_dir" ]]; then
        log_error "vcpkg directory not found: $vcpkg_dir"
        return 1
    fi
    
    # Check if vcpkg binary exists
    if [[ ! -x "$vcpkg_dir/vcpkg" ]]; then
        log_error "vcpkg binary not found or not executable"
        return 1
    fi
    
    # Test vcpkg command
    log_step "Testing vcpkg functionality..."
    cd "$vcpkg_dir" || return 1
    
    if ./vcpkg version &>/dev/null; then
        local vcpkg_version
        vcpkg_version=$(./vcpkg version | head -n1)
        log_success "vcpkg is functional: $vcpkg_version"
        return 0
    else
        log_error "vcpkg command failed"
        return 1
    fi
}

# 🧪 Verify C++20 compilation capability
verify_cpp20_compilation() {
    log_header "Verifying C++20 Compilation Capability"
    
    local test_dir="/tmp/cpp20_verification_test"
    local test_file="$test_dir/cpp20_test.cpp"
    local executable="$test_dir/cpp20_test"
    
    # Create test directory
    mkdir -p "$test_dir"
    
    # Create comprehensive C++20 test file
    create_cpp20_test_file "$test_file"
    
    # Test compilation with different compilers
    test_cpp20_with_clang "$test_file" "$executable"
    test_cpp20_with_gcc "$test_file" "$executable"
    
    # Test with vcpkg integration
    test_cpp20_with_vcpkg "$test_dir"
    
    # Cleanup
    rm -rf "$test_dir"
    
    log_success "C++20 compilation verification completed"
    return 0
}

# 📝 Create comprehensive C++20 test file
create_cpp20_test_file() {
    local test_file="$1"
    
    cat > "$test_file" << 'EOF'
#include <iostream>
#include <vector>
#include <ranges>
#include <concepts>
#include <format>
#include <coroutine>
#include <string_view>
#include <span>

// Test C++20 concepts
template<typename T>
concept Numeric = std::integral<T> || std::floating_point<T>;

template<Numeric T>
constexpr T square(T x) { return x * x; }

// Test C++20 ranges
void test_ranges() {
    std::vector<int> numbers{1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    auto even_squares = numbers 
        | std::views::filter([](int n) { return n % 2 == 0; })
        | std::views::transform(square<int>);
    
    std::cout << "Even squares: ";
    for (auto n : even_squares) {
        std::cout << n << " ";
    }
    std::cout << "\n";
}

// Test C++20 designated initializers
struct Point {
    int x, y;
    std::string name;
};

// Test C++20 string formatting (if available)
void test_modern_features() {
    // Designated initializers
    Point p{.x = 10, .y = 20, .name = "Origin"};
    std::cout << "Point: " << p.name << " at (" << p.x << ", " << p.y << ")\n";
    
    // String view and span
    std::string_view sv = "Hello C++20!";
    std::cout << "String view: " << sv << "\n";
    
    std::vector<int> vec = {1, 2, 3, 4, 5};
    std::span<int> sp(vec);
    std::cout << "Span size: " << sp.size() << "\n";
}

int main() {
    std::cout << "🔥 C++20 Feature Test Program\n";
    std::cout << "============================\n";
    
    // Test concepts
    std::cout << "Testing concepts: square(5) = " << square(5) << "\n";
    
    // Test ranges
    test_ranges();
    
    // Test other modern features
    test_modern_features();
    
    std::cout << "\n✅ All C++20 features tested successfully!\n";
    return 0;
}
EOF
}

# 🔨 Test C++20 compilation with Clang
test_cpp20_with_clang() {
    local test_file="$1"
    local executable="$2"
    
    log_step "Testing C++20 compilation with Clang..."
    
    local clang_cmd=""
    if command -v clang++ &>/dev/null; then
        if [[ "$SYSTEM_OS" == "macos" ]]; then
            # macOS: Try to use libc++ if available
            if clang++ -stdlib=libc++ -std=c++20 -x c++ /dev/null -o /dev/null 2>/dev/null; then
                clang_cmd="clang++ -std=c++20 -stdlib=libc++ -O2"
            else
                clang_cmd="clang++ -std=c++20 -O2"
            fi
        else
            # Linux: Check if libc++ is available, otherwise use libstdc++
            if clang++ -stdlib=libc++ -std=c++20 -x c++ /dev/null -o /dev/null 2>/dev/null; then
                clang_cmd="clang++ -std=c++20 -stdlib=libc++ -O2"
            else
                clang_cmd="clang++ -std=c++20 -O2"
            fi
        fi
        
        log_step "Compiling with: $clang_cmd"
        
        if $clang_cmd "$test_file" -o "$executable" 2>/dev/null; then
            log_success "Clang C++20 compilation successful"
            
            # Test execution
            if "$executable" &>/dev/null; then
                log_success "Clang-compiled C++20 program executed successfully"
            else
                log_warning "Clang-compiled program failed to execute"
            fi
        else
            log_warning "Clang C++20 compilation failed"
        fi
    else
        log_warning "Clang++ not found"
    fi
}

# 🔨 Test C++20 compilation with GCC
test_cpp20_with_gcc() {
    local test_file="$1"
    local executable="$2"
    
    log_step "Testing C++20 compilation with GCC..."
    
    if command -v g++ &>/dev/null; then
        local gcc_cmd="g++ -std=c++20 -O2"
        
        log_step "Compiling with: $gcc_cmd"
        
        if $gcc_cmd "$test_file" -o "$executable" 2>/dev/null; then
            log_success "GCC C++20 compilation successful"
            
            # Test execution
            if "$executable" &>/dev/null; then
                log_success "GCC-compiled C++20 program executed successfully"
            else
                log_warning "GCC-compiled program failed to execute"
            fi
        else
            log_warning "GCC C++20 compilation failed"
        fi
    else
        log_warning "g++ not found"
    fi
}

# 📦 Test C++20 with vcpkg integration
test_cpp20_with_vcpkg() {
    local test_dir="$1"
    
    log_step "Testing C++20 with vcpkg integration..."
    
    # Check if vcpkg is available
    if [[ ! -x "$HOME/.vcpkg/vcpkg" ]]; then
        log_warning "vcpkg not available for integration test"
        return 1
    fi
    
    # Create CMake project with vcpkg
    local cmake_file="$test_dir/CMakeLists.txt"
    local vcpkg_test_file="$test_dir/vcpkg_test.cpp"
    
    cat > "$cmake_file" << EOF
cmake_minimum_required(VERSION 3.20)
project(VcpkgTest)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Use vcpkg toolchain if available
if(DEFINED ENV{VCPKG_ROOT})
    set(CMAKE_TOOLCHAIN_FILE "\$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
endif()

find_package(fmt CONFIG QUIET)

add_executable(vcpkg_test vcpkg_test.cpp)

if(fmt_FOUND)
    target_link_libraries(vcpkg_test fmt::fmt)
    target_compile_definitions(vcpkg_test PRIVATE HAVE_FMT)
endif()
EOF
    
    cat > "$vcpkg_test_file" << 'EOF'
#include <iostream>
#include <vector>
#include <ranges>

#ifdef HAVE_FMT
#include <fmt/format.h>
#include <fmt/ranges.h>
#endif

int main() {
    std::vector<int> numbers{1, 2, 3, 4, 5};
    
#ifdef HAVE_FMT
    fmt::print("🔥 C++20 + vcpkg test with fmt library!\n");
    fmt::print("Numbers: {}\n", numbers);
#else
    std::cout << "🔥 C++20 + vcpkg test (without fmt library)\n";
    std::cout << "Numbers: ";
    for (auto n : numbers) {
        std::cout << n << " ";
    }
    std::cout << "\n";
#endif
    
    // Test ranges
    auto even_numbers = numbers | std::views::filter([](int n) { return n % 2 == 0; });
    
#ifdef HAVE_FMT
    fmt::print("Even numbers: {}\n", std::vector(even_numbers.begin(), even_numbers.end()));
#else
    std::cout << "Even numbers: ";
    for (auto n : even_numbers) {
        std::cout << n << " ";
    }
    std::cout << "\n";
#endif
    
    return 0;
}
EOF
    
    # Try to build with CMake
    cd "$test_dir" || return 1
    
    export VCPKG_ROOT="$HOME/.vcpkg"
    
    if command -v cmake &>/dev/null; then
        log_step "Building vcpkg integration test with CMake..."
        
        mkdir -p build
        cd build || return 1
        
        if cmake .. -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" &>/dev/null &&
           cmake --build . &>/dev/null; then
            log_success "vcpkg + CMake integration test successful"
            
            if ./vcpkg_test &>/dev/null; then
                log_success "vcpkg-integrated program executed successfully"
            else
                log_warning "vcpkg-integrated program failed to execute"
            fi
        else
            log_warning "vcpkg + CMake integration test failed"
        fi
    else
        log_warning "CMake not available for vcpkg integration test"
    fi
}

# 🎨 Setup environment configuration and aliases
setup_environment() {
    log_header "Setting up Environment Configuration"
    
    # Detect and configure for multiple shells
    configure_shell_environment
    
    # Setup C++20 aliases and functions
    setup_cpp20_aliases
    
    # Configure vcpkg environment
    setup_vcpkg_environment
    
    log_success "Environment configuration completed"
}

# 🐚 Configure environment for detected shell
configure_shell_environment() {
    local shell_configs=()
    
    # Detect available shells and their config files
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL:-}" == *"zsh"* ]]; then
        shell_configs+=("$HOME/.zshrc")
    fi
    
    if [[ -n "${BASH_VERSION:-}" ]] || [[ "${SHELL:-}" == *"bash"* ]]; then
        shell_configs+=("$HOME/.bashrc")
        shell_configs+=("$HOME/.bash_profile")
    fi
    
    # Add Fish shell support
    if [[ "${SHELL:-}" == *"fish"* ]]; then
        shell_configs+=("$HOME/.config/fish/config.fish")
        setup_fish_environment
        return
    fi
    
    # If no shell detected, default to common ones
    if [[ ${#shell_configs[@]} -eq 0 ]]; then
        shell_configs+=("$HOME/.bashrc" "$HOME/.zshrc")
    fi
    
    log_step "Configuring environment for shells: ${shell_configs[*]}"
    
    for config_file in "${shell_configs[@]}"; do
        if [[ -f "$config_file" ]]; then
            configure_shell_config "$config_file"
        else
            log_info "Creating $config_file..."
            touch "$config_file"
            configure_shell_config "$config_file"
        fi
    done
}

# ⚙️ Configure individual shell config file
configure_shell_config() {
    local config_file="$1"
    
    # Backup existing config
    if [[ -f "$config_file" ]] && [[ ! -f "$config_file.backup-cpp20" ]]; then
        cp "$config_file" "$config_file.backup-cpp20"
        log_info "Backed up $config_file to $config_file.backup-cpp20"
    fi
    
    # Check if our configuration already exists
    if grep -q "# 🔥 Modern C++20 Setup" "$config_file" 2>/dev/null; then
        log_info "C++20 configuration already exists in $config_file"
        return
    fi
    
    log_step "Adding C++20 configuration to $config_file..."
    
    cat >> "$config_file" << 'EOF'

# 🔥 Modern C++20 Setup - Auto-generated
# This section was added by the Ultimate C++20 Setup Script

# vcpkg configuration
export VCPKG_ROOT="$HOME/.vcpkg"
export PATH="$VCPKG_ROOT:$PATH"

# C++20 compiler preferences
export CXX_STANDARD=20
export CMAKE_CXX_STANDARD=20

# macOS specific: Prefer Homebrew LLVM
if [[ "$(uname)" == "Darwin" ]]; then
    if [[ -d "/opt/homebrew/opt/llvm/bin" ]]; then
        export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
        export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
        export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"
    elif [[ -d "/usr/local/opt/llvm/bin" ]]; then
        export PATH="/usr/local/opt/llvm/bin:$PATH"
        export LDFLAGS="-L/usr/local/opt/llvm/lib"
        export CPPFLAGS="-I/usr/local/opt/llvm/include"
    fi
fi

EOF
}

# 🐟 Setup Fish shell environment
setup_fish_environment() {
    local fish_config="$HOME/.config/fish/config.fish"
    
    # Create Fish config directory if it doesn't exist
    mkdir -p "$(dirname "$fish_config")"
    
    if grep -q "# Modern C++20 Setup" "$fish_config" 2>/dev/null; then
        log_info "Fish shell already configured"
        return
    fi
    
    log_step "Configuring Fish shell..."
    
    cat >> "$fish_config" << 'EOF'

# 🔥 Modern C++20 Setup - Auto-generated
# vcpkg configuration
set -gx VCPKG_ROOT "$HOME/.vcpkg"
set -gx PATH "$VCPKG_ROOT" $PATH

# C++20 compiler preferences
set -gx CXX_STANDARD 20
set -gx CMAKE_CXX_STANDARD 20

# macOS specific: Prefer Homebrew LLVM
if test (uname) = "Darwin"
    if test -d "/opt/homebrew/opt/llvm/bin"
        set -gx PATH "/opt/homebrew/opt/llvm/bin" $PATH
        set -gx LDFLAGS "-L/opt/homebrew/opt/llvm/lib"
        set -gx CPPFLAGS "-I/opt/homebrew/opt/llvm/include"
    else if test -d "/usr/local/opt/llvm/bin"
        set -gx PATH "/usr/local/opt/llvm/bin" $PATH
        set -gx LDFLAGS "-L/usr/local/opt/llvm/lib"
        set -gx CPPFLAGS "-I/usr/local/opt/llvm/include"
    end
end

EOF
}

# 🔥 Setup C++20 aliases and functions
setup_cpp20_aliases() {
    log_step "Setting up C++20 aliases and functions..."
    
    # For bash/zsh shells
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc")
    
    for config_file in "${shell_configs[@]}"; do
        if [[ -f "$config_file" ]]; then
            add_cpp20_aliases_to_config "$config_file"
        fi
    done
    
    # For Fish shell
    if [[ "${SHELL:-}" == *"fish"* ]] || command -v fish &>/dev/null; then
        setup_fish_cpp20_aliases
    fi
}

# 📝 Add C++20 aliases to bash/zsh config
add_cpp20_aliases_to_config() {
    local config_file="$1"
    
    if grep -q "alias cpp20=" "$config_file" 2>/dev/null; then
        log_info "C++20 aliases already exist in $config_file"
        return
    fi
    
    cat >> "$config_file" << 'EOF'

# 🔥 Modern C++20 Aliases
alias cpp20='clang++ -std=c++20 -stdlib=libc++'
alias cpp20-debug='clang++ -std=c++20 -stdlib=libc++ -g -O0 -Wall -Wextra -Wpedantic -fsanitize=address -fsanitize=undefined'
alias cpp20-release='clang++ -std=c++20 -stdlib=libc++ -O3 -DNDEBUG -march=native -flto'
alias cpp20-fast='clang++ -std=c++20 -stdlib=libc++ -O2'

# Linux specific: Use libstdc++ if libc++ not available
if [[ "$(uname)" == "Linux" ]]; then
    if ! clang++ -stdlib=libc++ -x c++ /dev/null -o /dev/null 2>/dev/null; then
        alias cpp20='clang++ -std=c++20'
        alias cpp20-debug='clang++ -std=c++20 -g -O0 -Wall -Wextra -Wpedantic -fsanitize=address -fsanitize=undefined'
        alias cpp20-release='clang++ -std=c++20 -O3 -DNDEBUG -march=native -flto'
        alias cpp20-fast='clang++ -std=c++20 -O2'
    fi
fi

# 🚀 Quick compile and run function
cpprun() {
    if [[ -z "$1" ]]; then
        echo "Usage: cpprun <file.cpp> [args...]"
        return 1
    fi
    
    local file="$1"
    local executable="${file%.*}"
    shift
    
    echo "🔨 Compiling $file..."
    if cpp20-fast "$file" -o "$executable"; then
        echo "🏃 Running $executable..."
        "./$executable" "$@"
        local exit_code=$?
        echo "💯 Program exited with code: $exit_code"
        return $exit_code
    else
        echo "❌ Compilation failed"
        return 1
    fi
}

# 🔧 Create new C++20 project
cpp20new() {
    local project_name="${1:-cpp20_project}"
    
    mkdir -p "$project_name"
    cd "$project_name" || return 1
    
    # Create basic CMakeLists.txt
    cat > CMakeLists.txt << EOF
cmake_minimum_required(VERSION 3.20)
project($project_name)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable($project_name main.cpp)

# Find and link vcpkg packages
find_package(PkgConfig REQUIRED)
EOF
    
    # Create basic main.cpp
    cat > main.cpp << 'EOF'
#include <iostream>
#include <vector>
#include <ranges>

int main() {
    std::cout << "🔥 Modern C++20 Project!\n";
    
    // Demonstrate some C++20 features
    std::vector<int> numbers{1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    auto even_numbers = numbers 
        | std::views::filter([](int n) { return n % 2 == 0; })
        | std::views::transform([](int n) { return n * n; });
    
    std::cout << "Even squares: ";
    for (auto n : even_numbers) {
        std::cout << n << " ";
    }
    std::cout << "\n";
    
    return 0;
}
EOF
    
    echo "🚀 Created C++20 project '$project_name'"
    echo "📁 Project directory: $(pwd)"
    echo "🔨 To build: mkdir build && cd build && cmake .. && make"
    echo "🏃 To run: ./build/$project_name"
}

# 🐟 Setup Fish shell C++20 aliases
setup_fish_cpp20_aliases() {
    local fish_functions_dir="$HOME/.config/fish/functions"
    mkdir -p "$fish_functions_dir"
    
    # Create Fish function files
    cat > "$fish_functions_dir/cpp20.fish" << 'EOF'
function cpp20 --description "Compile with C++20 standard"
    clang++ -std=c++20 -stdlib=libc++ $argv
end
EOF
    
    cat > "$fish_functions_dir/cpp20-debug.fish" << 'EOF'
function cpp20-debug --description "Compile with C++20 debug flags"
    clang++ -std=c++20 -stdlib=libc++ -g -O0 -Wall -Wextra -Wpedantic -fsanitize=address -fsanitize=undefined $argv
end
EOF
    
    cat > "$fish_functions_dir/cpprun.fish" << 'EOF'
function cpprun --description "Compile and run C++20 program"
    if test (count $argv) -eq 0
        echo "Usage: cpprun <file.cpp> [args...]"
        return 1
    end
    
    set file $argv[1]
    set executable (basename $file .cpp)
    set argv $argv[2..-1]
    
    echo "🔨 Compiling $file..."
    if cpp20-fast $file -o $executable
        echo "🏃 Running $executable..."
        ./$executable $argv
        set exit_code $status
        echo "💯 Program exited with code: $exit_code"
        return $exit_code
    else
        echo "❌ Compilation failed"
        return 1
    end
end
EOF
    
    log_success "Fish shell C++20 functions created"
}

# 📚 Setup vcpkg environment variables
setup_vcpkg_environment() {
    log_step "Setting up vcpkg environment variables..."
    
    # Export for current session
    export VCPKG_ROOT="$HOME/.vcpkg"
    export PATH="$VCPKG_ROOT:$PATH"
    
    # Verify vcpkg directory exists
    if [[ ! -d "$VCPKG_ROOT" ]]; then
        log_warning "vcpkg directory not found at $VCPKG_ROOT"
        log_info "vcpkg will be installed in the next step"
    else
        log_success "vcpkg environment configured"
    fi
}





# 🔨 Test C++20 compilation with Clang
test_cpp20_with_clang() {
    local test_file="$1"
    local executable="$2"
    
    log_step "Testing C++20 compilation with Clang..."
    
    local clang_cmd=""
    if command -v clang++ &>/dev/null; then
        if [[ "$SYSTEM_OS" == "macos" ]]; then
            # macOS: Try to use libc++ if available
            if clang++ -stdlib=libc++ -std=c++20 -x c++ /dev/null -o /dev/null 2>/dev/null; then
                clang_cmd="clang++ -std=c++20 -stdlib=libc++ -O2"
            else
                clang_cmd="clang++ -std=c++20 -O2"
            fi
        else
            # Linux: Check if libc++ is available, otherwise use libstdc++
            if clang++ -stdlib=libc++ -std=c++20 -x c++ /dev/null -o /dev/null 2>/dev/null; then
                clang_cmd="clang++ -std=c++20 -stdlib=libc++ -O2"
            else
                clang_cmd="clang++ -std=c++20 -O2"
            fi
        fi
        
        log_step "Compiling with: $clang_cmd"
        
        if $clang_cmd "$test_file" -o "$executable" 2>/dev/null; then
            log_success "Clang C++20 compilation successful"
            
            # Test execution
            if "$executable" &>/dev/null; then
                log_success "Clang-compiled C++20 program executed successfully"
            else
                log_warning "Clang-compiled program failed to execute"
            fi
        else
            log_warning "Clang C++20 compilation failed"
        fi
    else
        log_warning "Clang++ not found"
    fi
}

# 🔨 Test C++20 compilation with GCC
test_cpp20_with_gcc() {
    local test_file="$1"
    local executable="$2"
    
    log_step "Testing C++20 compilation with GCC..."
    
    if command -v g++ &>/dev/null; then
        local gcc_cmd="g++ -std=c++20 -O2"
        
        log_step "Compiling with: $gcc_cmd"
        
        if $gcc_cmd "$test_file" -o "$executable" 2>/dev/null; then
            log_success "GCC C++20 compilation successful"
            
            # Test execution
            if "$executable" &>/dev/null; then
                log_success "GCC-compiled C++20 program executed successfully"
            else
                log_warning "GCC-compiled program failed to execute"
            fi
        else
            log_warning "GCC C++20 compilation failed"
        fi
    else
        log_warning "g++ not found"
    fi
}

# 📦 Test C++20 with vcpkg integration
test_cpp20_with_vcpkg() {
    local test_dir="$1"
    
    log_step "Testing C++20 with vcpkg integration..."
    
    # Check if vcpkg is available
    if [[ ! -x "$HOME/.vcpkg/vcpkg" ]]; then
        log_warning "vcpkg not available for integration test"
        return 1
    fi
    
    # Create CMake project with vcpkg
    local cmake_file="$test_dir/CMakeLists.txt"
    local vcpkg_test_file="$test_dir/vcpkg_test.cpp"
    
    cat > "$cmake_file" << EOF
cmake_minimum_required(VERSION 3.20)
project(VcpkgTest)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Use vcpkg toolchain if available
if(DEFINED ENV{VCPKG_ROOT})
    set(CMAKE_TOOLCHAIN_FILE "\$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
endif()

find_package(fmt CONFIG QUIET)

add_executable(vcpkg_test vcpkg_test.cpp)

if(fmt_FOUND)
    target_link_libraries(vcpkg_test fmt::fmt)
    target_compile_definitions(vcpkg_test PRIVATE HAVE_FMT)
endif()
EOF
    
    cat > "$vcpkg_test_file" << 'EOF'
#include <iostream>
#include <vector>
#include <ranges>

#ifdef HAVE_FMT
#include <fmt/format.h>
#include <fmt/ranges.h>
#endif

int main() {
    std::vector<int> numbers{1, 2, 3, 4, 5};
    
#ifdef HAVE_FMT
    fmt::print("🔥 C++20 + vcpkg test with fmt library!\n");
    fmt::print("Numbers: {}\n", numbers);
#else
    std::cout << "🔥 C++20 + vcpkg test (without fmt library)\n";
    std::cout << "Numbers: ";
    for (auto n : numbers) {
        std::cout << n << " ";
    }
    std::cout << "\n";
#endif
    
    // Test ranges
    auto even_numbers = numbers | std::views::filter([](int n) { return n % 2 == 0; });
    
#ifdef HAVE_FMT
    fmt::print("Even numbers: {}\n", std::vector(even_numbers.begin(), even_numbers.end()));
#else
    std::cout << "Even numbers: ";
    for (auto n : even_numbers) {
        std::cout << n << " ";
    }
    std::cout << "\n";
#endif
    
    return 0;
}
EOF
    
    # Try to build with CMake
    cd "$test_dir" || return 1
    
    export VCPKG_ROOT="$HOME/.vcpkg"
    
    if command -v cmake &>/dev/null; then
        log_step "Building vcpkg integration test with CMake..."
        
        mkdir -p build
        cd build || return 1
        
        if cmake .. -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" &>/dev/null &&
           cmake --build . &>/dev/null; then
            log_success "vcpkg + CMake integration test successful"
            
            if ./vcpkg_test &>/dev/null; then
                log_success "vcpkg-integrated program executed successfully"
            else
                log_warning "vcpkg-integrated program failed to execute"
            fi
        else
            log_warning "vcpkg + CMake integration test failed"
        fi
    else
        log_warning "CMake not available for vcpkg integration test"
    fi
}

# 🔍 Verify installation
verify_installation() {
    log_header "Verifying Installation"
    
    local errors=0
    
    # Check vcpkg specifically
    log_step "Checking vcpkg installation..."
    if [[ -d "$VCPKG_DIR" ]]; then
        if [[ -d "$VCPKG_DIR/.git" ]]; then
            log_success "vcpkg directory is a valid git repository"
        else
            log_warning "vcpkg directory exists but is not a git repository"
        fi
        
        if [[ -x "$VCPKG_DIR/vcpkg" ]]; then
            log_success "vcpkg binary is executable"
        else
            log_warning "vcpkg binary not found or not executable"
        fi
    else
        log_error "vcpkg directory not found"
        ((errors++))
    fi
    
    # Check tools
    local tools=("cmake" "ninja" "clang++" "vcpkg")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            log_success "$tool: $(${tool} --version | head -n1)"
        else
            log_error "$tool: Not found"
            ((errors++))
        fi
    done
    
    # Test compile
    log_step "Testing C++20 compilation..."
    
    local test_file="/tmp/cpp20_test.cpp"
    cat > "$test_file" << 'EOF'
#include <iostream>
#include <vector>
#include <ranges>
#include <concepts>

template<typename T>
concept Numeric = std::integral<T> || std::floating_point<T>;

template<Numeric T>
T square(T x) { return x * x; }

int main() {
    std::vector<int> numbers{1, 2, 3, 4, 5};
    auto squares = numbers | std::views::transform(square<int>);
    
    for (auto s : squares) {
        std::cout << s << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
EOF
    
    if clang++ -std=c++20 -stdlib=libc++ "$test_file" -o "/tmp/cpp20_test" &>/dev/null; then
        log_success "C++20 compilation test passed"
        rm -f "/tmp/cpp20_test" "$test_file"
    else
        log_error "C++20 compilation test failed"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "All checks passed!"
        return 0
    else
        log_error "$errors check(s) failed"
        return 1
    fi
}

# 🎉 Show completion message
show_completion() {
    log_header "Setup Complete!"
    
    echo -e "${GREEN}"
    cat << 'EOF'
🎉 Your essential C++20 development environment is ready!

📋 What was installed:
  ✅ Homebrew package manager
  ✅ Essential development tools (CMake, Ninja, Clang, GCC)
  ✅ vcpkg package manager
  ✅ C++20 compilation aliases

🚀 Quick start:
  1. Restart your terminal or run: source ~/.zshrc
  2. Test compilation: echo '#include <iostream>\nint main() { std::cout << "Hello C++20!"; }' > test.cpp && cpprun test.cpp

💡 Available commands:
  cpp20 file.cpp           - Quick compile with C++20
  cpp20-debug file.cpp     - Compile with debug flags and sanitizers
  cpp20-release file.cpp   - Compile with optimizations
  cpprun file.cpp          - Compile and run in one command

🔧 Tools available:
  cmake, ninja, clang++, gcc, vcpkg, jq

🆘 Need help?
  Visit: https://github.com/your-repo/cpp20-setup
EOF
    echo -e "${NC}"
}

# 🚀 Main execution
main() {
    show_banner
    
    log_info "Starting Ultimate C++20 Setup..."
    echo
    
    # Check if running with curl | bash
    if [[ -t 0 ]]; then
        read -p "Continue with installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    else
        log_info "Running in non-interactive mode"
    fi
    
    # Execute setup steps
    check_prerequisites
    install_package_managers
    install_dev_tools
    setup_environment
    setup_vcpkg
    
    echo
    if verify_installation; then
        show_completion
    else
        log_error "Setup completed with errors. Please check the output above."
        exit 1
    fi
}

# Execute main function
main "$@"