#!/bin/bash

# 📦 VCPKG HELPER SCRIPT
# Modernizes vcpkg workflow to be more like npm/cargo
# Usage: vcpkg-helper.sh {add|remove|list|update|search} [package]

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}" >&2; }

# Check if we're in a C++ project
check_project() {
    if [[ ! -f "CMakeLists.txt" ]]; then
        log_error "Not in a C++ project directory (no CMakeLists.txt found)"
        log_info "Run this command from your project root directory"
        exit 1
    fi
}

# Initialize vcpkg.json if it doesn't exist
init_vcpkg_json() {
    if [[ ! -f "vcpkg.json" ]]; then
        local project_name=$(basename "$(pwd)")
        log_info "Creating vcpkg.json..."
        
        cat > vcpkg.json << EOF
{
  "name": "$project_name",
  "version": "1.0.0",
  "description": "C++20 project using vcpkg",
  "dependencies": []
}
EOF
        log_success "vcpkg.json created"
    fi
}

# Add package to vcpkg.json
add_package() {
    local package="$1"
    
    if [[ -z "$package" ]]; then
        log_error "Package name required"
        echo "Usage: vcpkg-helper.sh add <package-name>"
        exit 1
    fi
    
    check_project
    init_vcpkg_json
    
    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        log_error "jq is required for this operation"
        log_info "Install with: brew install jq"
        exit 1
    fi
    
    # Check if package already exists
    if jq -e ".dependencies[] | select(. == \"$package\" or .name == \"$package\")" vcpkg.json >/dev/null 2>&1; then
        log_warning "Package '$package' already in vcpkg.json"
        return 0
    fi
    
    # Add package
    log_info "Adding '$package' to vcpkg.json..."
    
    # Handle both string and object format
    local temp_file=$(mktemp)
    if [[ "$package" == *":"* ]] || [[ "$package" == *"["* ]]; then
        # Complex package specification
        jq ".dependencies += [{\"name\": \"$(echo "$package" | cut -d: -f1)\", \"features\": [\"$(echo "$package" | cut -d: -f2)\"]}]" vcpkg.json > "$temp_file"
    else
        # Simple package name
        jq ".dependencies += [\"$package\"]" vcpkg.json > "$temp_file"
    fi
    
    mv "$temp_file" vcpkg.json
    log_success "Package '$package' added to vcpkg.json"
    
    # Auto-install if vcpkg is available
    if command -v vcpkg &>/dev/null; then
        log_info "Installing dependencies..."
        vcpkg install
        log_success "Dependencies installed"
    else
        log_warning "vcpkg not found in PATH. Run 'vcpkg install' manually."
    fi
}

# Remove package from vcpkg.json
remove_package() {
    local package="$1"
    
    if [[ -z "$package" ]]; then
        log_error "Package name required"
        echo "Usage: vcpkg-helper.sh remove <package-name>"
        exit 1
    fi
    
    check_project
    
    if [[ ! -f "vcpkg.json" ]]; then
        log_error "No vcpkg.json found"
        exit 1
    fi
    
    if ! command -v jq &>/dev/null; then
        log_error "jq is required for this operation"
        exit 1
    fi
    
    log_info "Removing '$package' from vcpkg.json..."
    
    local temp_file=$(mktemp)
    jq "del(.dependencies[] | select(. == \"$package\" or .name == \"$package\"))" vcpkg.json > "$temp_file"
    mv "$temp_file" vcpkg.json
    
    log_success "Package '$package' removed from vcpkg.json"
}

# List installed packages
list_packages() {
    check_project
    
    echo -e "${CYAN}📦 Project Dependencies:${NC}"
    echo "======================="
    
    if [[ -f "vcpkg.json" ]]; then
        if command -v jq &>/dev/null; then
            echo "📋 vcpkg.json dependencies:"
            jq -r '.dependencies[]' vcpkg.json | while read -r dep; do
                if [[ "$dep" == "{"* ]]; then
                    # Object format
                    echo "$dep" | jq -r '"  • " + .name + (if .features then " [" + (.features | join(", ")) + "]" else "" end)'
                else
                    # String format
                    echo "  • $dep"
                fi
            done
        else
            echo "📄 vcpkg.json exists (install 'jq' for detailed view)"
        fi
    else
        echo "📄 No vcpkg.json found"
    fi
    
    echo
    echo "💾 Installed packages:"
    if command -v vcpkg &>/dev/null; then
        if [[ -d "vcpkg_installed" ]]; then
            find vcpkg_installed -name "*.pc" -exec basename {} .pc \; 2>/dev/null | sort | uniq | while read -r pkg; do
                echo "  ✅ $pkg"
            done
        else
            echo "  No packages installed yet"
        fi
    else
        echo "  vcpkg not available"
    fi
}

# Update packages
update_packages() {
    check_project
    
    log_info "Updating vcpkg packages..."
    
    if command -v vcpkg &>/dev/null; then
        # Update vcpkg itself
        cd "$VCPKG_ROOT" && git pull
        
        # Rebuild packages
        cd - >/dev/null
        vcpkg install --recurse
        
        log_success "Packages updated"
    else
        log_error "vcpkg not found"
        exit 1
    fi
}

# Search packages
search_packages() {
    local query="$1"
    
    if [[ -z "$query" ]]; then
        log_error "Search query required"
        echo "Usage: vcpkg-helper.sh search <query>"
        exit 1
    fi
    
    log_info "Searching for packages containing '$query'..."
    
    if command -v vcpkg &>/dev/null; then
        vcpkg search "$query" | head -20
    else
        log_warning "vcpkg not available, searching online..."
        curl -s "https://vcpkg.io/en/packages.html" | grep -i "$query" | head -10 || echo "No results found"
    fi
}

# Show package info
info_package() {
    local package="$1"
    
    if [[ -z "$package" ]]; then
        log_error "Package name required"
        echo "Usage: vcpkg-helper.sh info <package-name>"
        exit 1
    fi
    
    log_info "Package information for '$package':"
    
    if command -v vcpkg &>/dev/null; then
        vcpkg show "$package"
    else
        log_warning "vcpkg not available"
    fi
}

# Clean vcpkg cache
clean_vcpkg() {
    check_project
    
    log_warning "Cleaning vcpkg installation..."
    
    read -p "Remove vcpkg_installed directory? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf vcpkg_installed/
        log_success "vcpkg installation cleaned"
    else
        log_info "Clean cancelled"
    fi
}

# Show help
show_help() {
    cat << 'EOF'
📦 vcpkg Helper - Modern Package Management for C++

USAGE:
    vcpkg-helper.sh <command> [arguments]

COMMANDS:
    add <package>       Add package to vcpkg.json and install
    remove <package>    Remove package from vcpkg.json  
    list               List project dependencies
    update             Update all packages
    search <query>     Search for packages
    info <package>     Show package information
    clean              Clean vcpkg installation
    init               Initialize vcpkg.json
    help               Show this help

EXAMPLES:
    vcpkg-helper.sh add fmt
    vcpkg-helper.sh add "opencv[contrib]"
    vcpkg-helper.sh remove spdlog
    vcpkg-helper.sh search json
    vcpkg-helper.sh list
    vcpkg-helper.sh update

ADVANCED:
    # Add package with features
    vcpkg-helper.sh add "boost[system,filesystem]"
    
    # Add specific version (when supported)
    vcpkg-helper.sh add "fmt>=9.0.0"

NOTES:
    • Run from your C++ project root directory
    • Requires jq for JSON manipulation: brew install jq
    • Auto-installs packages when vcpkg is available
    • Works with vcpkg manifest mode (vcpkg.json)
EOF
}

# Main command dispatch
main() {
    case "${1:-help}" in
        "add")
            add_package "${2:-}"
            ;;
        "remove"|"rm")
            remove_package "${2:-}"
            ;;
        "list"|"ls")
            list_packages
            ;;
        "update"|"upgrade")
            update_packages
            ;;
        "search"|"find")
            search_packages "${2:-}"
            ;;
        "info"|"show")
            info_package "${2:-}"
            ;;
        "clean")
            clean_vcpkg
            ;;
        "init")
            check_project
            init_vcpkg_json
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "Unknown command: ${1:-}"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"