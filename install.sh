#!/usr/bin/env bash

# 🚀 ULTIMATE C++20 INSTALLER
# Streamlined one-command environment setup for C++20 development
# Usage: curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash

set -euo pipefail

# Color definitions for logging
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration constants
readonly REPO_BASE="https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/helpers"
readonly LOG_FILE="/tmp/cpp20-setup.log"
readonly MIN_BASH_VERSION="3.0"

# Logging functions
log_info() { 
    echo -e "${BLUE}ℹ️  $*${NC}" | tee -a "$LOG_FILE"
}

log_success() { 
    echo -e "${GREEN}✅ $*${NC}" | tee -a "$LOG_FILE"
}

log_warning() { 
    echo -e "${YELLOW}⚠️  $*${NC}" | tee -a "$LOG_FILE"
}

log_error() { 
    echo -e "${RED}❌ $*${NC}" | tee -a "$LOG_FILE" >&2
}

log_header() { 
    echo -e "${PURPLE}${BOLD}🚀 $*${NC}" | tee -a "$LOG_FILE"
}

# Function to detect platform
detect_platform() {
    log_info "Detecting platform..."
    
    local platform
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ $(uname -m) == "arm64" ]]; then
            platform="macos-arm64"
        else
            platform="macos-x64"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Check for specific Linux distributions
        if [[ -f "/etc/os-release" ]]; then
            source /etc/os-release
            case "$ID" in
                ubuntu|debian)
                    platform="linux-debian"
                    ;;
                centos|rhel|fedora)
                    platform="linux-rhel"
                    ;;
                arch)
                    platform="linux-arch"
                    ;;
                *)
                    platform="linux-generic"
                    ;;
            esac
        else
            platform="linux-generic"
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        platform="windows"
    else
        platform="unknown"
    fi
    
    echo "$platform"
    log_info "Detected platform: $platform"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check bash version
    local bash_version
    bash_version=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [[ $(echo "$bash_version >= $MIN_BASH_VERSION" | bc -l 2>/dev/null || echo 0) -eq 0 ]]; then
        log_error "Bash version $MIN_BASH_VERSION+ required, found $bash_version"
        exit 1
    fi
    
    # Check required tools
    local required_tools=("curl" "git")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        
        # Provide installation hints based on platform
        local platform
        platform=$(detect_platform)
        
        case "$platform" in
            "macos-"*)
                log_info "Install missing tools with: brew install ${missing_tools[*]}"
                ;;
            "linux-debian")
                log_info "Install missing tools with: sudo apt-get update && sudo apt-get install -y ${missing_tools[*]}"
                ;;
            "linux-rhel")
                log_info "Install missing tools with: sudo yum install -y ${missing_tools[*]}"
                ;;
            "linux-arch")
                log_info "Install missing tools with: sudo pacman -S ${missing_tools[*]}"
                ;;
            *)
                log_info "Please install the missing tools: ${missing_tools[*]}"
                ;;
        esac
        
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Function to install tools
install_tools() {
    log_header "Installing C++20 development tools..."
    
    local platform
    platform=$(detect_platform)
    
    case "$platform" in
        "unknown")
            log_error "Unsupported platform: $platform"
            exit 1
            ;;
        "windows")
            log_warning "Windows support is experimental. Consider using WSL2."
            ;;
    esac
    
    # Download and execute the main setup script
    log_info "Downloading setup script from $REPO_BASE/setup-cpp20-ultimate.sh"
    
    if curl -fsSL "$REPO_BASE/setup-cpp20-ultimate.sh" | bash; then
        log_success "C++20 development tools installed successfully"
    else
        log_error "Failed to install C++20 development tools"
        exit 1
    fi
    
    # Setup project creation tools
    log_info "Setting up project creation tools..."
    
    if curl -fsSL "$REPO_BASE/create-cpp20-project.sh" >/dev/null 2>&1; then
        log_success "Project creation tools verified"
    else
        log_warning "Project creation tools may not be available"
    fi
    
    # Setup package management tools
    log_info "Setting up package management tools..."
    
    if curl -fsSL "$REPO_BASE/tools_vckg_helper.sh" >/dev/null 2>&1; then
        log_success "Package management tools verified"
    else
        log_warning "Package management tools may not be available"
    fi
}

# Function to setup environment
setup_environment() {
    log_header "Setting up environment configuration..."
    
    local shell_config
    
    # Detect user's shell and set appropriate config file
    case "$SHELL" in
        */zsh)
            shell_config="$HOME/.zshrc"
            ;;
        */bash)
            shell_config="$HOME/.bashrc"
            ;;
        */fish)
            shell_config="$HOME/.config/fish/config.fish"
            log_warning "Fish shell detected. Manual configuration may be required."
            ;;
        *)
            shell_config="$HOME/.profile"
            log_warning "Unknown shell detected. Using .profile"
            ;;
    esac
    
    # Backup existing configuration
    if [[ -f "$shell_config" ]]; then
        cp "$shell_config" "$shell_config.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backed up existing shell configuration"
    fi
    
    # Add C++20 development aliases and functions
    log_info "Adding C++20 development tools to $shell_config"
    
    cat >> "$shell_config" << 'EOF'

# 🚀 C++20 Development Environment
# Added by Ultimate C++20 Setup

# Project creation using modern template system
cpp-new() {
    if [[ -z "$1" ]]; then
        echo "Usage: cpp-new <project-name> [console|library]"
        echo "       cpp-new <project-name> --local  # Use local template system"
        echo "       cpp-new <project-name> --remote # Use remote script (fallback)"
        return 1
    fi
    
    local project_name="$1"
    local project_type="${2:-console}"
    local mode="auto"
    
    # Parse arguments
    case "$2" in
        --local)
            mode="local"
            project_type="console"
            ;;
        --remote)
            mode="remote"
            project_type="console"
            ;;
        console|library)
            project_type="$2"
            ;;
    esac
    
    echo "🏗️ Creating C++20 project: $project_name ($project_type)"
    
    # Try local template system first, fallback to remote
    if [[ "$mode" == "remote" ]] || { [[ "$mode" == "auto" ]] && ! [[ -f "helpers/create-cpp20-project.sh" || -f "./create-cpp20-project.sh" ]]; }; then
        echo "📡 Using remote script..."
        curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/helpers/create-cpp20-project.sh | bash -s -- "$project_name" "$project_type"
    else
        echo "🏠 Using local template system..."
        local script_path=""
        
        # Find the local script
        if [[ -f "helpers/create-cpp20-project.sh" ]]; then
            script_path="helpers/create-cpp20-project.sh"
        elif [[ -f "./create-cpp20-project.sh" ]]; then
            script_path="./create-cpp20-project.sh"
        elif [[ -f "$HOME/.local/bin/create-cpp20-project.sh" ]]; then
            script_path="$HOME/.local/bin/create-cpp20-project.sh"
        else
            echo "⚠️  Local template system not found, falling back to remote..."
            curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/helpers/create-cpp20-project.sh | bash -s -- "$project_name" "$project_type"
            return
        fi
        
        # Check if template system is available
        local template_dir="$(dirname "$script_path")"
        if [[ -d "$template_dir/../templates" ]] || [[ -d "templates" ]]; then
            "$script_path" "$project_name" "$project_type"
        else
            echo "⚠️  Templates directory not found, falling back to remote..."
            curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/helpers/create-cpp20-project.sh | bash -s -- "$project_name" "$project_type"
        fi
    fi
}

# Setup modern template system locally
setup-cpp20-templates() {
    echo "📦 Installing C++20 template system locally..."
    
    local install_dir="${1:-$HOME/.local/share/cpp20-templates}"
    
    # Create installation directory
    mkdir -p "$install_dir"
    cd "$install_dir"
    
    # Clone or download the template system
    if command -v git &>/dev/null; then
        echo "🔗 Cloning template repository..."
        git clone https://github.com/danielsalles/setup_cpp20.git . || {
            echo "⚠️  Git clone failed, trying direct download..."
            curl -fsSL https://github.com/danielsalles/setup_cpp20/archive/main.tar.gz | tar -xz --strip-components=1
        }
    else
        echo "📥 Downloading template files..."
        curl -fsSL https://github.com/danielsalles/setup_cpp20/archive/main.tar.gz | tar -xz --strip-components=1
    fi
    
    # Install Python dependencies if needed
    if command -v python3 &>/dev/null; then
        echo "🐍 Installing Python dependencies..."
        python3 -m pip install --user jinja2 || echo "⚠️  Failed to install jinja2, install manually with: pip install jinja2"
    fi
    
    # Make scripts executable
    chmod +x helpers/*.sh 2>/dev/null || true
    
    # Create symlinks for easy access
    mkdir -p "$HOME/.local/bin"
    ln -sf "$install_dir/helpers/create-cpp20-project.sh" "$HOME/.local/bin/create-cpp20-project.sh"
    ln -sf "$install_dir/helpers/process_templates.sh" "$HOME/.local/bin/process-templates"
    
    echo "✅ Template system installed to: $install_dir"
    echo "💡 Local templates are now available for cpp-new command"
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "📝 Adding $HOME/.local/bin to PATH..."
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
}

# Package management
vcpkg-helper() {
    curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/helpers/tools_vckg_helper.sh | bash -s -- "$@"
}

# Package management aliases
alias vcpkg-add='vcpkg-helper add'
alias vcpkg-remove='vcpkg-helper remove'
alias vcpkg-list='vcpkg-helper list'
alias vcpkg-search='vcpkg-helper search'

# Template system aliases
alias cpp-console='cpp-new'  # Create console project (default)
alias cpp-lib='cpp-new $(basename $(pwd)) library'  # Create library project
alias cpp-templates-setup='setup-cpp20-templates'  # Install templates locally
alias cpp-templates-update='setup-cpp20-templates'  # Update templates

# Template processing aliases (when using local system)
alias process-templates='$HOME/.local/bin/process-templates'
alias jinja-cpp='process-templates'

# Quick compile aliases
alias cpp20='g++ -std=c++20 -Wall -Wextra'
alias cpp20-debug='g++ -std=c++20 -Wall -Wextra -g -O0'
alias cpp20-release='g++ -std=c++20 -Wall -Wextra -O3 -DNDEBUG'

# Compile and run
cpprun() {
    if [[ -z "$1" ]]; then
        echo "Usage: cpprun <file.cpp>"
        return 1
    fi
    
    local filename="${1%.*}"
    cpp20 "$1" -o "$filename" && "./$filename"
}

EOF
    
    log_success "Environment configuration completed"
    log_info "Configuration added to: $shell_config"
}

# Cleanup function for error handling
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Installation failed with exit code $exit_code"
        log_info "Check the log file for details: $LOG_FILE"
    fi
    exit $exit_code
}

# Set up signal trapping for cleanup
trap cleanup EXIT

# Main execution function
main() {
    # Initialize log file
    echo "=== C++20 Setup Log - $(date) ===" > "$LOG_FILE"
    
    log_header "Ultimate C++20 Development Setup"
    log_info "Starting streamlined installation process..."
    
    # Execute setup steps
    detect_platform
    check_prerequisites
    install_tools
    setup_environment
    
    # Success message
    log_header "🎉 Setup Complete!"
    cat << 'EOF'

🎉 Your C++20 development environment is ready!

🚀 Quick start:
  # Restart your terminal or run:
  source ~/.zshrc  # (or your shell config file)
  
  # Create a new project:
  cpp-new my-awesome-project console
  
  # Navigate and build:
  cd my-awesome-project
  ./scripts/build.sh

💡 Available commands:
  # Project creation (modern template system)
  cpp-new <name> [console|library] - Create new C++20 project
  cpp-new <name> --local           - Force local template system
  cpp-new <name> --remote          - Force remote script
  setup-cpp20-templates            - Install templates locally
  
  # Package management
  vcpkg-add <package>          - Add package
  vcpkg-remove <package>       - Remove package  
  vcpkg-list                   - List packages
  vcpkg-search <query>         - Search packages
  
  # Quick development
  cpp20 file.cpp               - Quick compile with C++20
  cpp20-debug file.cpp         - Compile with debug flags
  cpp20-release file.cpp       - Compile optimized release
  cpprun file.cpp              - Compile and run
  
  # Template processing (advanced)
  process-templates <type> <name>  - Process templates directly
  jinja-cpp <type> <name>          - Alias for template processing

📚 Need help?
  Visit: https://github.com/danielsalles/setup_cpp20

EOF
    
    log_warning "Please restart your terminal or run: source ~/.zshrc"
    log_success "Installation completed successfully!"
}

# Execute main function with all arguments
main "$@"