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

# 🔍 System detection
detect_system() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ $(uname -m) == "arm64" ]]; then
            echo "macos-arm64"
        else
            echo "macos-x64"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
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
    echo -e "${CYAN}System: $(detect_system)${NC}"
    echo
}

# 🔍 Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    # Check macOS version
    if [[ $(detect_system) == "macos"* ]]; then
        local macos_version=$(sw_vers -productVersion)
        log_info "macOS version: $macos_version"
        
        # Check if version is compatible (macOS 11+)
        if [[ $(echo "$macos_version" | cut -d. -f1) -lt 11 ]]; then
            log_error "macOS 11.0 or later required"
            exit 1
        fi
    fi
    
    # Check for Xcode Command Line Tools
    if ! xcode-select -p &>/dev/null; then
        log_warning "Xcode Command Line Tools not found"
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        log_info "Please complete Xcode installation and run this script again"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# 📦 Install Homebrew
install_homebrew() {
    log_header "Installing Homebrew"
    
    if command -v brew &>/dev/null; then
        log_info "Homebrew already installed: $(brew --version | head -n1)"
        log_step "Updating Homebrew..."
        brew update
    else
        log_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add to PATH for Apple Silicon
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
            export PATH="/opt/homebrew/bin:$PATH"
        fi
    fi
    
    log_success "Homebrew ready"
}

# 🔧 Install development tools
install_dev_tools() {
    log_header "Installing Development Tools"
    
    local tools=(
        "cmake"          # Build system generator
        "ninja"          # Fast build system
        "pkg-config"     # Package configuration
        "llvm"           # Modern Clang with C++20
        "gcc"            # GCC compiler
        "git"            # Version control
        "jq"             # JSON processor
    )
    
    log_step "Installing essential tools..."
    for tool in "${tools[@]}"; do
        if brew list "$tool" &>/dev/null; then
            log_info "$tool already installed"
        else
            log_step "Installing $tool..."
            brew install "$tool"
        fi
    done
    
    # Install Python 3 if not present
    if ! command -v python3 &>/dev/null; then
        log_step "Installing Python 3..."
        brew install python
    fi
    
    log_success "Development tools installed"
}

# 📚 Setup vcpkg
setup_vcpkg() {
    log_header "Setting up vcpkg"
    
    if [[ -d "$VCPKG_DIR" ]]; then
        log_info "vcpkg already exists at $VCPKG_DIR"
        log_step "Updating vcpkg..."
        cd "$VCPKG_DIR"
        git pull
        ./bootstrap-vcpkg.sh
    else
        log_step "Cloning vcpkg..."
        git clone https://github.com/Microsoft/vcpkg.git "$VCPKG_DIR"
        cd "$VCPKG_DIR"
        
        log_step "Bootstrapping vcpkg..."
        ./bootstrap-vcpkg.sh
        
        log_step "Integrating vcpkg..."
        ./vcpkg integrate install
    fi
    
    # Add to environment
    cat >> ~/.zshrc << 'EOF'

# vcpkg configuration
export VCPKG_ROOT="$HOME/.vcpkg"
export PATH="$VCPKG_ROOT:$PATH"
EOF
    
    export VCPKG_ROOT="$VCPKG_DIR"
    export PATH="$VCPKG_ROOT:$PATH"
    
    log_success "vcpkg configured"
}

# 🎨 Setup aliases and functions
setup_aliases() {
    log_header "Setting up Aliases and Functions"
    
    cat >> ~/.zshrc << 'EOF'

# 🔥 Modern C++20 Aliases
alias cpp20='clang++ -std=c++20 -stdlib=libc++'
alias cpp20-debug='clang++ -std=c++20 -stdlib=libc++ -g -O0 -Wall -Wextra -Wpedantic -fsanitize=address -fsanitize=undefined'
alias cpp20-release='clang++ -std=c++20 -stdlib=libc++ -O3 -DNDEBUG -march=native -flto'
alias cpp20-fast='clang++ -std=c++20 -stdlib=libc++ -O2'

# 🚀 Quick compile and run
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
    else
        echo "❌ Compilation failed"
        return 1
    fi
}
EOF
    
    log_success "Aliases and functions configured"
}



# 🔍 Verify installation
verify_installation() {
    log_header "Verifying Installation"
    
    local errors=0
    
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
    install_homebrew
    install_dev_tools
    setup_vcpkg
    setup_aliases
    
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