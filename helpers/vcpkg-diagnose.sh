#!/bin/bash

# 🔍 VCPKG DIAGNOSTIC SCRIPT
# Helps diagnose vcpkg installation and package issues
# Usage: ./vcpkg-diagnose.sh

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
log_header() { echo -e "${CYAN}🔍 $*${NC}"; }

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                🔍 VCPKG DIAGNOSTIC TOOL                      ║
║                                                              ║
║  Diagnoses vcpkg installation and package issues            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

check_environment() {
    log_header "Environment Check"
    
    # Check VCPKG_ROOT
    if [[ -n "${VCPKG_ROOT:-}" ]]; then
        log_success "VCPKG_ROOT is set: $VCPKG_ROOT"
        
        if [[ -d "$VCPKG_ROOT" ]]; then
            log_success "VCPKG_ROOT directory exists"
            
            if [[ -x "$VCPKG_ROOT/vcpkg" ]]; then
                log_success "vcpkg binary is executable"
                echo "  Version: $($VCPKG_ROOT/vcpkg version)"
            else
                log_error "vcpkg binary not found or not executable"
            fi
        else
            log_error "VCPKG_ROOT directory does not exist"
        fi
    else
        log_error "VCPKG_ROOT environment variable not set"
        log_info "Add to ~/.zshrc: export VCPKG_ROOT=\"\$HOME/.vcpkg\""
    fi
    
    # Check PATH
    if command -v vcpkg &>/dev/null; then
        log_success "vcpkg found in PATH: $(which vcpkg)"
    else
        log_warning "vcpkg not found in PATH"
        log_info "Add to ~/.zshrc: export PATH=\"\$VCPKG_ROOT:\$PATH\""
    fi
    
    # Check toolchain file
    local toolchain_file="${VCPKG_ROOT:-}/scripts/buildsystems/vcpkg.cmake"
    if [[ -f "$toolchain_file" ]]; then
        log_success "vcpkg CMake toolchain file exists"
    else
        log_error "vcpkg CMake toolchain file not found"
    fi
    
    echo
}

check_project() {
    log_header "Project Check"
    
    # Check if in project directory
    if [[ -f "CMakeLists.txt" ]]; then
        log_success "Found CMakeLists.txt"
    else
        log_warning "No CMakeLists.txt found - not in a C++ project directory?"
    fi
    
    # Check vcpkg.json
    if [[ -f "vcpkg.json" ]]; then
        log_success "Found vcpkg.json"
        
        if command -v jq &>/dev/null; then
            echo "  Dependencies:"
            jq -r '.dependencies[]' vcpkg.json | while read -r dep; do
                echo "    • $dep"
            done
        else
            log_warning "jq not found - install with: brew install jq"
        fi
    else
        log_warning "No vcpkg.json found"
        log_info "Create with: vcpkg-helper init"
    fi
    
    # Check vcpkg_installed
    if [[ -d "vcpkg_installed" ]]; then
        log_success "Found vcpkg_installed directory"
        local installed_count=$(find vcpkg_installed -name "*.pc" 2>/dev/null | wc -l)
        echo "  Installed packages: $installed_count"
    else
        log_warning "No vcpkg_installed directory found"
        log_info "Run: vcpkg install"
    fi
    
    echo
}

check_packages() {
    log_header "Package Check"
    
    if [[ ! -f "vcpkg.json" ]]; then
        log_warning "No vcpkg.json found - skipping package check"
        return
    fi
    
    if ! command -v vcpkg &>/dev/null; then
        log_error "vcpkg command not available"
        return
    fi
    
    # Check each package in vcpkg.json
    if command -v jq &>/dev/null; then
        jq -r '.dependencies[]' vcpkg.json | while read -r dep; do
            # Extract package name (handle both string and object format)
            local pkg_name
            if [[ "$dep" == "{"* ]]; then
                pkg_name=$(echo "$dep" | jq -r '.name')
            else
                pkg_name="$dep"
            fi
            
            echo "Checking package: $pkg_name"
            
            # Check if package is available in vcpkg
            if vcpkg search "$pkg_name" | grep -q "^$pkg_name "; then
                log_success "  Package '$pkg_name' is available in vcpkg"
            else
                log_warning "  Package '$pkg_name' not found in vcpkg registry"
            fi
            
            # Check if package is installed
            if [[ -d "vcpkg_installed" ]] && find vcpkg_installed -name "*$pkg_name*" | grep -q .; then
                log_success "  Package '$pkg_name' appears to be installed"
            else
                log_warning "  Package '$pkg_name' not installed"
            fi
        done
    fi
    
    echo
}

check_cmake_integration() {
    log_header "CMake Integration Check"
    
    if [[ ! -f "CMakeLists.txt" ]]; then
        log_warning "No CMakeLists.txt found - skipping CMake check"
        return
    fi
    
    # Check for vcpkg toolchain usage
    if grep -q "CMAKE_TOOLCHAIN_FILE" CMakeLists.txt; then
        log_success "CMakeLists.txt references CMAKE_TOOLCHAIN_FILE"
    else
        log_warning "CMakeLists.txt doesn't reference CMAKE_TOOLCHAIN_FILE"
        log_info "Add: -DCMAKE_TOOLCHAIN_FILE=\$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake"
    fi
    
    # Check for vcpkg helper functions
    if [[ -f "cmake/VcpkgHelpers.cmake" ]]; then
        log_success "Found VcpkgHelpers.cmake"
        
        if grep -q "vcpkg_find_packages" CMakeLists.txt; then
            log_success "CMakeLists.txt uses vcpkg_find_packages()"
        else
            log_warning "CMakeLists.txt doesn't call vcpkg_find_packages()"
        fi
    else
        log_warning "VcpkgHelpers.cmake not found"
    fi
    
    # Check test configuration
    if [[ -f "tests/CMakeLists.txt" ]]; then
        log_success "Found tests/CMakeLists.txt"
        
        if grep -q "catch_discover_tests" tests/CMakeLists.txt; then
            log_warning "tests/CMakeLists.txt uses catch_discover_tests (may cause issues)"
            log_info "Consider using simple add_test() instead"
        elif grep -q "add_test" tests/CMakeLists.txt; then
            log_success "tests/CMakeLists.txt uses add_test() (recommended)"
        fi
        
        if grep -q "include(Catch)" tests/CMakeLists.txt; then
            log_warning "tests/CMakeLists.txt includes Catch module (may cause issues)"
        fi
    fi
    
    echo
}

suggest_fixes() {
    log_header "Suggested Fixes"
    
    echo "If you're having issues with vcpkg packages:"
    echo
    echo "1. 🔧 Ensure vcpkg is properly installed:"
    echo "   export VCPKG_ROOT=\"\$HOME/.vcpkg\""
    echo "   export PATH=\"\$VCPKG_ROOT:\$PATH\""
    echo
    echo "2. 📦 Install packages manually:"
    echo "   vcpkg install fmt spdlog catch2"
    echo
    echo "3. 🏗️ Build with vcpkg toolchain:"
    echo "   cmake -B build -DCMAKE_TOOLCHAIN_FILE=\$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake"
    echo "   cmake --build build"
    echo
    echo "4. 🧹 Clean and rebuild:"
    echo "   rm -rf build vcpkg_installed"
    echo "   vcpkg install"
    echo "   ./scripts/build.sh"
    echo
    echo "5. 🔍 Check package names:"
    echo "   vcpkg search fmt"
    echo "   vcpkg search spdlog"
    echo
    echo "6. 🧪 Fix test configuration issues:"
    echo "   Replace catch_discover_tests() with add_test() in tests/CMakeLists.txt"
    echo "   Remove include(Catch) if causing problems"
    echo "   Use simple: add_test(NAME my_tests COMMAND my_tests)"
    echo
}

main() {
    show_banner
    
    check_environment
    check_project
    check_packages
    check_cmake_integration
    suggest_fixes
    
    log_info "Diagnostic complete!"
}

main "$@" 