#!/bin/bash

# 🚀 ULTIMATE C++20 INSTALLER
# Complete wizard for C++20 development environment setup
# Usage: curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# GitHub repository details
readonly REPO_BASE="https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/helpers"

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}" >&2; }
log_header() { echo -e "${PURPLE}${BOLD}🚀 $*${NC}"; }

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           🚀 ULTIMATE C++20 DEVELOPMENT SETUP                ║
║                                                              ║
║  Complete wizard for modern C++20 development:               ║
║  • Environment Setup: Essential tools and compilers          ║
║  • Project Creation: Modern C++20 project templates          ║
║  • Package Management: vcpkg helper tools                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

detect_system() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ $(uname -m) == "arm64" ]]; then
            echo "macos-arm64"
        else
            echo "macos-x64"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

check_prerequisites() {
    local system=$(detect_system)
    
    log_info "Detected system: $system"
    
    case $system in
        "macos-"*)
            if ! command -v curl &>/dev/null; then
                log_error "curl is required but not found"
                exit 1
            fi
            ;;
        "linux")
            if ! command -v curl &>/dev/null; then
                log_error "curl is required. Install with: sudo apt-get install curl"
                exit 1
            fi
            ;;
        "windows")
            log_warning "Windows support is experimental. Consider using WSL2."
            ;;
        *)
            log_warning "Unsupported system: $system"
            log_info "This installer is optimized for macOS and Linux"
            ;;
    esac
}

download_and_run() {
    local script_name="$1"
    local script_args="${2:-}"
    
    log_info "Downloading and executing $script_name..."
    
    if curl -fsSL "$REPO_BASE/$script_name" | bash -s -- $script_args; then
        log_success "$script_name completed successfully"
    else
        log_error "$script_name failed"
        exit 1
    fi
}

setup_environment() {
    log_header "Step 1: C++20 Environment Setup"
    
    echo -e "${CYAN}This will install:${NC}"
    echo "• Essential development tools (CMake, Ninja, Clang, GCC)"
    echo "• vcpkg package manager"
    echo "• C++20 compilation aliases (cpp20, cpp20-debug, etc.)"
    echo "• Takes ~5-10 minutes"
    echo
    
    read -p "Install C++20 development environment? (Y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Skipping environment setup"
        return 1
    fi
    
    download_and_run "setup-cpp20-ultimate.sh"
    
    log_success "🎉 C++20 environment setup completed!"
    return 0
}

setup_project_creator() {
    log_header "Step 2: Project Creation Tool"
    
    echo -e "${CYAN}This will setup:${NC}"
    echo "• cpp-new command for creating C++20 projects"
    echo "• Support for console, library, and GUI project types"
    echo "• Modern CMake configuration with vcpkg integration"
    echo "• Automatic testing framework setup"
    echo
    
    read -p "Setup project creation tool? (Y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Skipping project creator setup"
        return 1
    fi
    
    log_info "Adding cpp-new alias to ~/.zshrc..."
    
    # Add cpp-new alias
    cat >> ~/.zshrc << 'EOF'

# 🏗️ C++20 Project Creator
cpp-new() {
    if [[ -z "$1" ]]; then
        echo "Usage: cpp-new <project-name> [console|library|gui]"
        return 1
    fi
    
    local project_name="$1"
    local project_type="${2:-console}"
    
    echo "🏗️ Creating C++20 project: $project_name ($project_type)"
    curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/helpers/create-cpp20-project.sh | bash -s -- "$project_name" "$project_type"
}
EOF
    
    log_success "cpp-new command configured!"
    log_info "Usage: cpp-new my-project [console|library|gui]"
    return 0
}

setup_vcpkg_helper() {
    log_header "Step 3: vcpkg Package Management Helper"
    
    echo -e "${CYAN}This will setup:${NC}"
    echo "• vcpkg-helper command for modern package management"
    echo "• npm-like experience: add, remove, list, search packages"
    echo "• Automatic vcpkg.json management"
    echo "• Integration with project workflow"
    echo
    
    read -p "Setup vcpkg helper tools? (Y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Skipping vcpkg helper setup"
        return 1
    fi
    
    log_info "Adding vcpkg-helper alias to ~/.zshrc..."
    
    # Add vcpkg-helper alias
    cat >> ~/.zshrc << 'EOF'

# 📦 vcpkg Helper Tool
vcpkg-helper() {
    curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/helpers/tools_vckg_helper.sh | bash -s -- "$@"
}

# Convenient aliases
alias vcpkg-add='vcpkg-helper add'
alias vcpkg-remove='vcpkg-helper remove'
alias vcpkg-list='vcpkg-helper list'
alias vcpkg-search='vcpkg-helper search'
EOF
    
    log_success "vcpkg-helper commands configured!"
    log_info "Usage: vcpkg-helper add fmt, vcpkg-add spdlog, vcpkg-list"
    return 0
}

create_first_project() {
    log_header "Step 4: Create Your First Project (Optional)"
    
    echo -e "${CYAN}Create a sample C++20 project to test your setup${NC}"
    echo
    
    read -p "Create a sample project? (Y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Skipping project creation"
        return 1
    fi
    
    read -p "Project name (default: hello-cpp20): " project_name
    project_name="${project_name:-hello-cpp20}"
    
    echo "Project types:"
    echo "1. Console application (default)"
    echo "2. Static/shared library"
    echo "3. GUI application"
    
    read -p "Choose type (1-3): " -n 1 -r
    echo
    
    local project_type="console"
    case $REPLY in
        2) project_type="library" ;;
        3) project_type="gui" ;;
    esac
    
    download_and_run "create-cpp20-project.sh" "$project_name $project_type"
    
    log_success "Project '$project_name' created!"
    log_info "Next steps:"
    log_info "  cd $project_name"
    log_info "  ./scripts/build.sh"
    return 0
}

show_completion() {
    log_header "🎉 Setup Complete!"
    
    echo -e "${GREEN}"
    cat << 'EOF'
🎉 Your C++20 development environment is ready!

📋 What was configured:
  ✅ C++20 development environment (CMake, Ninja, Clang, vcpkg)
  ✅ Project creation tool (cpp-new command)
  ✅ Package management helper (vcpkg-helper commands)

🚀 Quick start commands:
  # Restart your terminal first, then:
  
  # Create a new project
  cpp-new my-awesome-project console
  
  # Navigate and build
  cd my-awesome-project
  ./scripts/build.sh
  
  # Add packages to your project
  vcpkg-add fmt
  vcpkg-add spdlog
  vcpkg-list

💡 Available commands:
  cpp-new <name> [type]        - Create new C++20 project
  vcpkg-helper <command>       - Package management
  vcpkg-add <package>          - Add package (shortcut)
  vcpkg-remove <package>       - Remove package (shortcut)
  vcpkg-list                   - List packages (shortcut)
  vcpkg-search <query>         - Search packages (shortcut)

🔧 Development aliases:
  cpp20 file.cpp               - Quick compile with C++20
  cpp20-debug file.cpp         - Compile with debug flags
  cpp20-release file.cpp       - Compile with optimizations
  cpprun file.cpp              - Compile and run

📚 Project types supported:
  • console    - Console applications
  • library    - Static/shared libraries
  • gui        - GUI applications (with framework support)

🆘 Need help?
  Visit: https://github.com/danielsalles/setup_cpp20
EOF
    echo -e "${NC}"
}

show_help() {
    cat << 'EOF'
🚀 Ultimate C++20 Development Setup

USAGE:
    curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash
    
    # Or with arguments:
    curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash -s -- [OPTION]

OPTIONS:
    --all           Complete setup (all components)
    --env-only      Environment setup only
    --tools-only    Project and package tools only
    --help          Show this help

COMPONENTS:
    1. Environment Setup (setup-cpp20-ultimate.sh)
       • CMake, Ninja, Clang, GCC
       • vcpkg package manager
       • C++20 compilation aliases
    
    2. Project Creator (create-cpp20-project.sh)
       • cpp-new command for project creation
       • Modern C++20 templates
       • CMake best practices
    
    3. Package Helper (tools_vckg_helper.sh)
       • vcpkg-helper commands
       • npm-like package management
       • Automatic vcpkg.json handling

EXAMPLES:
    # Interactive wizard (default)
    curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash
    
    # Complete automated setup
    curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash -s -- --all
    
    # Environment only
    curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash -s -- --env-only

AFTER INSTALLATION:
    # Create your first project
    cpp-new my-project console
    cd my-project
    ./scripts/build.sh
    
    # Add packages
    vcpkg-add fmt spdlog
    vcpkg-list
EOF
}

interactive_wizard() {
    local env_setup=false
    local project_setup=false
    local vcpkg_setup=false
    local sample_project=false
    
    log_info "Welcome to the C++20 Development Setup Wizard!"
    echo
    
    # Step 1: Environment
    if setup_environment; then
        env_setup=true
        echo
    fi
    
    # Step 2: Project Creator
    if setup_project_creator; then
        project_setup=true
        echo
    fi
    
    # Step 3: vcpkg Helper
    if setup_vcpkg_helper; then
        vcpkg_setup=true
        echo
    fi
    
    # Step 4: Sample Project
    if [[ "$env_setup" == true ]] && [[ "$project_setup" == true ]]; then
        if create_first_project; then
            sample_project=true
        fi
    fi
    
    echo
    show_completion
    
    if [[ "$env_setup" == true ]] || [[ "$project_setup" == true ]] || [[ "$vcpkg_setup" == true ]]; then
        echo
        log_warning "Please restart your terminal or run: source ~/.zshrc"
    fi
}

automated_setup() {
    local mode="$1"
    
    case "$mode" in
        "--all")
            log_header "Complete Automated Setup"
            download_and_run "setup-cpp20-ultimate.sh"
            setup_project_creator
            setup_vcpkg_helper
            ;;
        "--env-only")
            log_header "Environment Setup Only"
            download_and_run "setup-cpp20-ultimate.sh"
            ;;
        "--tools-only")
            log_header "Tools Setup Only"
            setup_project_creator
            setup_vcpkg_helper
            ;;
        *)
            log_error "Unknown option: $mode"
            show_help
            exit 1
            ;;
    esac
    
    show_completion
    log_warning "Please restart your terminal or run: source ~/.zshrc"
}

main() {
    show_banner
    check_prerequisites
    
    case "${1:-interactive}" in
        "--all"|"--env-only"|"--tools-only")
            automated_setup "$1"
            ;;
        "--help"|"-h")
            show_help
            ;;
        "interactive"|*)
            interactive_wizard
            ;;
    esac
}

main "$@"