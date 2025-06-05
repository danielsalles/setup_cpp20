#!/bin/bash

# {{ project_name }} Dependencies Update Script
# Update vcpkg and other project dependencies

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Platform detection
readonly OS_TYPE="$(uname -s)"

# Logging functions with emojis
log_info() {
    if [[ "${QUIET:-false}" != true ]]; then
        echo -e "${BLUE}ℹ️  [INFO]${NC} $*"
    fi
}

log_success() {
    if [[ "${QUIET:-false}" != true ]]; then
        echo -e "${GREEN}✅ [SUCCESS]${NC} $*"
    fi
}

log_warning() {
    if [[ "${QUIET:-false}" != true ]]; then
        echo -e "${YELLOW}⚠️  [WARNING]${NC} $*"
    fi
}

log_error() {
    echo -e "${RED}❌ [ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${VERBOSE:-false}" == true ]]; then
        echo -e "${PURPLE}🔍 [DEBUG]${NC} $*"
    fi
}

# Find vcpkg installation
find_vcpkg() {
    local vcpkg_paths=(
        "$VCPKG_ROOT"
        "$HOME/.vcpkg"
        "/usr/local/vcpkg"
        "/opt/vcpkg"
        "$PROJECT_ROOT/vcpkg"
        "$PROJECT_ROOT/../vcpkg"
    )
    
    for path in "${vcpkg_paths[@]}"; do
        if [[ -n "$path" ]] && [[ -f "$path/vcpkg" ]] || [[ -f "$path/vcpkg.exe" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    # Try to find in PATH
    if command -v vcpkg >/dev/null 2>&1; then
        local vcpkg_path
        vcpkg_path="$(command -v vcpkg)"
        echo "$(dirname "$vcpkg_path")"
        return 0
    fi
    
    return 1
}

# Check vcpkg version
check_vcpkg_version() {
    local vcpkg_cmd="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would check vcpkg version"
        return 0
    fi
    
    log_debug "Checking vcpkg version..."
    
    if "$vcpkg_cmd" version 2>/dev/null; then
        return 0
    else
        log_warning "Could not retrieve vcpkg version"
        return 1
    fi
}

# Update vcpkg itself
update_vcpkg() {
    local vcpkg_root="$1"
    local vcpkg_cmd="$vcpkg_root/vcpkg"
    
    if [[ "$OS_TYPE" == "CYGWIN"* ]] || [[ "$OS_TYPE" == "MINGW"* ]] || [[ "$OS_TYPE" == "MSYS"* ]]; then
        vcpkg_cmd="$vcpkg_root/vcpkg.exe"
    fi
    
    if [[ "$UPDATE_VCPKG" != true ]]; then
        log_debug "Skipping vcpkg self-update (--skip-vcpkg-update)"
        return 0
    fi
    
    log_info "Updating vcpkg itself..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would update vcpkg from Git and rebuild"
        return 0
    fi
    
    # Save current directory
    local current_dir
    current_dir="$(pwd)"
    
    cd "$vcpkg_root"
    
    # Pull latest changes if this is a git repository
    if [[ -d ".git" ]]; then
        log_debug "Pulling latest vcpkg updates from Git..."
        if git pull origin master 2>/dev/null || git pull origin main 2>/dev/null; then
            log_debug "Updated vcpkg from Git"
        else
            log_warning "Could not update vcpkg from Git (not fatal)"
        fi
    fi
    
    # Bootstrap/rebuild vcpkg
    log_debug "Rebuilding vcpkg..."
    if [[ -f "bootstrap-vcpkg.sh" ]] && [[ "$OS_TYPE" != "CYGWIN"* ]] && [[ "$OS_TYPE" != "MINGW"* ]] && [[ "$OS_TYPE" != "MSYS"* ]]; then
        ./bootstrap-vcpkg.sh -disableMetrics
    elif [[ -f "bootstrap-vcpkg.bat" ]]; then
        ./bootstrap-vcpkg.bat -disableMetrics
    else
        log_warning "No bootstrap script found for vcpkg"
    fi
    
    cd "$current_dir"
    
    log_success "vcpkg updated successfully"
}

# Update project dependencies using vcpkg manifest
update_vcpkg_dependencies() {
    local vcpkg_cmd="$1"
    
    log_info "Updating vcpkg dependencies..."
    
    # Check for vcpkg.json manifest
    if [[ ! -f "$PROJECT_ROOT/vcpkg.json" ]]; then
        log_warning "No vcpkg.json manifest found in project root"
        log_info "You may need to run 'vcpkg new --application' to create one"
        return 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would install/update dependencies from vcpkg.json"
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Remove vcpkg_installed to force fresh install if requested
    if [[ "$FORCE_REINSTALL" == true ]] && [[ -d "vcpkg_installed" ]]; then
        log_debug "Removing existing vcpkg_installed directory..."
        rm -rf vcpkg_installed
    fi
    
    # Install/update dependencies
    local vcpkg_args=(
        install
        --triplet="${TRIPLET:-x64-linux}"
    )
    
    if [[ "$VERBOSE" == true ]]; then
        vcpkg_args+=(--debug)
    fi
    
    log_debug "Running: $vcpkg_cmd ${vcpkg_args[*]}"
    
    if "$vcpkg_cmd" "${vcpkg_args[@]}"; then
        log_success "Dependencies updated successfully"
        
        # Show installed packages if verbose
        if [[ "$VERBOSE" == true ]]; then
            log_info "Installed packages:"
            "$vcpkg_cmd" list --triplet="${TRIPLET:-x64-linux}" 2>/dev/null || true
        fi
    else
        log_error "Failed to update dependencies"
        return 1
    fi
}

# Upgrade specific packages
upgrade_packages() {
    local vcpkg_cmd="$1"
    shift
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_debug "No specific packages to upgrade"
        return 0
    fi
    
    log_info "Upgrading specific packages: ${packages[*]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would upgrade packages: ${packages[*]}"
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    for package in "${packages[@]}"; do
        log_debug "Upgrading package: $package"
        
        if "$vcpkg_cmd" upgrade "$package" --triplet="${TRIPLET:-x64-linux}"; then
            log_success "Upgraded: $package"
        else
            log_warning "Failed to upgrade: $package"
        fi
    done
}

# Generate integration files
generate_integration() {
    local vcpkg_cmd="$1"
    
    if [[ "$SKIP_INTEGRATION" == true ]]; then
        log_debug "Skipping integration generation (--skip-integration)"
        return 0
    fi
    
    log_info "Generating vcpkg integration files..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would generate CMake integration files"
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Generate CMake integration
    if "$vcpkg_cmd" integrate install 2>/dev/null; then
        log_debug "Generated global CMake integration"
    else
        log_debug "Could not generate global integration (may require admin)"
    fi
    
    # For local project integration, ensure vcpkg toolchain is used
    if [[ -f "CMakeLists.txt" ]]; then
        local vcpkg_toolchain="$("$vcpkg_cmd" integrate cmake 2>/dev/null | grep -o '[^[:space:]]*vcpkg.cmake' | head -1)" || true
        
        if [[ -n "$vcpkg_toolchain" ]] && [[ -f "$vcpkg_toolchain" ]]; then
            log_debug "vcpkg toolchain available at: $vcpkg_toolchain"
            
            # Check if CMAKE_TOOLCHAIN_FILE is mentioned in CMakeLists.txt
            if ! grep -q "CMAKE_TOOLCHAIN_FILE" CMakeLists.txt 2>/dev/null; then
                log_info "Consider adding vcpkg toolchain to your CMakeLists.txt:"
                echo "  set(CMAKE_TOOLCHAIN_FILE \"$vcpkg_toolchain\")"
            fi
        fi
    fi
}

# Check for outdated packages
check_outdated() {
    local vcpkg_cmd="$1"
    
    log_info "Checking for outdated packages..."
    
    cd "$PROJECT_ROOT"
    
    # This is informational only
    if "$vcpkg_cmd" list --outdated --triplet="${TRIPLET:-x64-linux}" 2>/dev/null; then
        return 0
    else
        log_debug "Could not check for outdated packages"
        return 1
    fi
}

# Validate dependencies
validate_dependencies() {
    local vcpkg_cmd="$1"
    
    log_info "Validating dependencies..."
    
    cd "$PROJECT_ROOT"
    
    # Check if vcpkg.json is valid
    if command -v jq >/dev/null 2>&1; then
        if ! jq empty vcpkg.json 2>/dev/null; then
            log_error "vcpkg.json is not valid JSON"
            return 1
        fi
        log_debug "vcpkg.json is valid JSON"
    fi
    
    # Check if dependencies are actually installed
    if [[ -f "vcpkg.json" ]]; then
        local dependencies
        if command -v jq >/dev/null 2>&1; then
            dependencies=$(jq -r '.dependencies[]? // empty' vcpkg.json 2>/dev/null)
        else
            # Fallback parsing without jq
            dependencies=$(grep -o '"[^"]*"' vcpkg.json | grep -v '"dependencies"' | sed 's/"//g' | head -20)
        fi
        
        if [[ -n "$dependencies" ]]; then
            log_debug "Checking installed status of dependencies..."
            
            local missing_count=0
            while IFS= read -r dep; do
                if [[ -n "$dep" ]]; then
                    if ! "$vcpkg_cmd" list | grep -q "^$dep:"; then
                        log_warning "Dependency not installed: $dep"
                        ((missing_count++)) || true
                    else
                        log_debug "✓ $dep is installed"
                    fi
                fi
            done <<< "$dependencies"
            
            if [[ "$missing_count" -gt 0 ]]; then
                log_warning "$missing_count dependencies are missing"
                return 1
            else
                log_success "All dependencies are installed"
            fi
        fi
    fi
}

# Show dependency information
show_info() {
    if [[ "$QUIET" == true ]]; then
        return
    fi
    
    log_info "Dependency Update Summary:"
    echo "  Project: {{ project_name }}"
    echo "  Project Root: $PROJECT_ROOT"
    echo "  Mode: $([ "$DRY_RUN" == true ] && echo "Dry Run" || echo "Execute")"
    echo "  Update vcpkg: $([ "$UPDATE_VCPKG" == true ] && echo "Yes" || echo "No")"
    echo "  Force Reinstall: $([ "$FORCE_REINSTALL" == true ] && echo "Yes" || echo "No")"
    echo "  Target Triplet: ${TRIPLET:-x64-linux}"
    
    if [[ -n "${VCPKG_ROOT:-}" ]]; then
        echo "  vcpkg Root: $VCPKG_ROOT"
    fi
}

# Print usage information
print_usage() {
    cat << EOF
${BOLD}{{ project_name }} Dependencies Update Script${NC}
Update vcpkg and other project dependencies

${BOLD}USAGE:${NC}
    $0 [OPTIONS] [PACKAGES...]

${BOLD}UPDATE OPTIONS:${NC}
    --all                   Update everything (vcpkg + dependencies)
    --deps-only             Update only project dependencies (default)
    --vcpkg-only            Update only vcpkg itself
    --packages PKG1,PKG2    Update specific packages only

${BOLD}BEHAVIOR OPTIONS:${NC}
    --force-reinstall       Remove and reinstall all dependencies
    --skip-vcpkg-update     Don't update vcpkg itself
    --skip-integration      Don't generate CMake integration files
    --check-outdated        Show outdated packages and exit
    --validate-only         Only validate dependencies, don't update

${BOLD}CONFIGURATION OPTIONS:${NC}
    --triplet TRIPLET       Target triplet (default: x64-linux)
    --vcpkg-root PATH       Path to vcpkg installation

${BOLD}BEHAVIOR OPTIONS:${NC}
    -n, --dry-run           Show what would be updated without actually updating
    -v, --verbose           Enable verbose output with detailed information
    -q, --quiet             Suppress non-essential output
    --color                 Force colored output
    --no-color              Disable colored output

${BOLD}UTILITY OPTIONS:${NC}
    -h, --help              Show this help message

${BOLD}EXAMPLES:${NC}
    $0                              # Update project dependencies
    $0 --all                        # Update vcpkg and dependencies
    $0 --check-outdated             # Check for outdated packages
    $0 --force-reinstall            # Clean reinstall all dependencies
    $0 --packages fmt,spdlog        # Update specific packages
    $0 --dry-run --verbose          # Preview updates with details
    $0 --triplet x64-windows        # Update for Windows target

${BOLD}DEPENDENCY SOURCES:${NC}
    vcpkg:      Uses vcpkg.json manifest in project root
    System:     Updates vcpkg installation itself

${BOLD}NOTES:${NC}
    - Requires vcpkg.json manifest in project root
    - Will auto-detect vcpkg installation or use VCPKG_ROOT
    - Use --force-reinstall to fix corrupted dependencies
    - Integration files help CMake find vcpkg packages

EOF
}

# Default values
UPDATE_ALL=false
UPDATE_DEPS_ONLY=true
UPDATE_VCPKG_ONLY=false
UPDATE_PACKAGES=()
FORCE_REINSTALL=false
UPDATE_VCPKG=false
SKIP_INTEGRATION=false
CHECK_OUTDATED=false
VALIDATE_ONLY=false
TRIPLET=""
CUSTOM_VCPKG_ROOT=""
DRY_RUN=false
VERBOSE=false
QUIET=false
FORCE_COLOR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            UPDATE_ALL=true
            UPDATE_DEPS_ONLY=false
            UPDATE_VCPKG_ONLY=false
            UPDATE_VCPKG=true
            shift
            ;;
        --deps-only)
            UPDATE_DEPS_ONLY=true
            UPDATE_ALL=false
            UPDATE_VCPKG_ONLY=false
            shift
            ;;
        --vcpkg-only)
            UPDATE_VCPKG_ONLY=true
            UPDATE_ALL=false
            UPDATE_DEPS_ONLY=false
            UPDATE_VCPKG=true
            shift
            ;;
        --packages)
            IFS=',' read -ra UPDATE_PACKAGES <<< "$2"
            shift 2
            ;;
        --force-reinstall)
            FORCE_REINSTALL=true
            shift
            ;;
        --skip-vcpkg-update)
            UPDATE_VCPKG=false
            shift
            ;;
        --skip-integration)
            SKIP_INTEGRATION=true
            shift
            ;;
        --check-outdated)
            CHECK_OUTDATED=true
            shift
            ;;
        --validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        --triplet)
            TRIPLET="$2"
            shift 2
            ;;
        --vcpkg-root)
            CUSTOM_VCPKG_ROOT="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --color)
            FORCE_COLOR=true
            shift
            ;;
        --no-color)
            FORCE_COLOR=false
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            # Treat remaining args as packages
            UPDATE_PACKAGES+=("$1")
            shift
            ;;
    esac
done

# Handle color output
if [[ "$FORCE_COLOR" == false ]] || [[ ! -t 1 ]] || [[ "$QUIET" == true ]]; then
    RED="" GREEN="" YELLOW="" BLUE="" PURPLE="" CYAN="" BOLD="" NC=""
fi

# Set default triplet based on OS
if [[ -z "$TRIPLET" ]]; then
    case "$OS_TYPE" in
        Darwin*)
            TRIPLET="x64-osx"
            ;;
        Linux*)
            TRIPLET="x64-linux"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            TRIPLET="x64-windows"
            ;;
        *)
            TRIPLET="x64-linux"
            ;;
    esac
fi

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    # Print header
    if [[ "$QUIET" != true ]]; then
        log_info "Starting {{ project_name }} dependencies update..."
        echo
    fi
    
    show_info
    
    if [[ "$QUIET" != true ]]; then
        echo
    fi
    
    # Find vcpkg
    local vcpkg_root
    if [[ -n "$CUSTOM_VCPKG_ROOT" ]]; then
        vcpkg_root="$CUSTOM_VCPKG_ROOT"
    else
        if ! vcpkg_root=$(find_vcpkg); then
            log_error "vcpkg not found. Please install vcpkg or set VCPKG_ROOT environment variable"
            log_info "Visit: https://github.com/Microsoft/vcpkg"
            exit 1
        fi
    fi
    
    local vcpkg_cmd="$vcpkg_root/vcpkg"
    if [[ "$OS_TYPE" == "CYGWIN"* ]] || [[ "$OS_TYPE" == "MINGW"* ]] || [[ "$OS_TYPE" == "MSYS"* ]]; then
        vcpkg_cmd="$vcpkg_root/vcpkg.exe"
    fi
    
    if [[ ! -x "$vcpkg_cmd" ]]; then
        log_error "vcpkg executable not found or not executable: $vcpkg_cmd"
        exit 1
    fi
    
    log_debug "Using vcpkg: $vcpkg_cmd"
    
    # Check vcpkg version
    check_vcpkg_version "$vcpkg_cmd"
    
    # Execute requested operations
    if [[ "$CHECK_OUTDATED" == true ]]; then
        check_outdated "$vcpkg_cmd"
        exit 0
    fi
    
    if [[ "$VALIDATE_ONLY" == true ]]; then
        validate_dependencies "$vcpkg_cmd"
        exit $?
    fi
    
    # Update vcpkg itself if requested
    if [[ "$UPDATE_VCPKG" == true ]] || [[ "$UPDATE_VCPKG_ONLY" == true ]]; then
        update_vcpkg "$vcpkg_root"
        
        if [[ "$UPDATE_VCPKG_ONLY" == true ]]; then
            log_success "vcpkg update completed"
            exit 0
        fi
    fi
    
    # Update dependencies
    if [[ "$UPDATE_DEPS_ONLY" == true ]] || [[ "$UPDATE_ALL" == true ]]; then
        if [[ ${#UPDATE_PACKAGES[@]} -gt 0 ]]; then
            upgrade_packages "$vcpkg_cmd" "${UPDATE_PACKAGES[@]}"
        else
            update_vcpkg_dependencies "$vcpkg_cmd"
        fi
    fi
    
    # Generate integration
    if [[ "$UPDATE_DEPS_ONLY" == true ]] || [[ "$UPDATE_ALL" == true ]]; then
        generate_integration "$vcpkg_cmd"
    fi
    
    # Validate final state
    if [[ "$UPDATE_DEPS_ONLY" == true ]] || [[ "$UPDATE_ALL" == true ]]; then
        validate_dependencies "$vcpkg_cmd"
    fi
    
    # Final summary
    if [[ "$QUIET" != true ]]; then
        echo
        if [[ "$DRY_RUN" == true ]]; then
            log_success "Dry run completed - no dependencies were actually updated"
        else
            log_success "{{ project_name }} dependencies update completed!"
        fi
    fi
}

# Run main function
main "$@" 