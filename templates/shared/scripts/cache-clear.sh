#!/bin/bash

# {{ project_name }} CMake Cache Clear Script
# Clear CMake cache and reconfigure project from scratch

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly BUILD_DIR="${PROJECT_ROOT}/build"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

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

# Clear CMake cache files
clear_cmake_cache() {
    log_info "Clearing CMake cache files..."
    
    local cmake_files=(
        "CMakeCache.txt"
        "CMakeFiles"
        "cmake_install.cmake"
        "CTestTestfile.cmake" 
        "install_manifest.txt"
        "CPackConfig.cmake"
        "CPackSourceConfig.cmake"
        "_deps"
    )
    
    local removed_count=0
    
    for file in "${cmake_files[@]}"; do
        if [[ -e "$BUILD_DIR/$file" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_info "Would remove: $file"
            else
                rm -rf "$BUILD_DIR/$file"
                log_debug "Removed: $file"
            fi
            ((removed_count++)) || true
        fi
    done
    
    log_debug "Cleared $removed_count CMake cache items"
}

# Clear vcpkg cache
clear_vcpkg_cache() {
    log_info "Clearing vcpkg cache..."
    
    local vcpkg_files=(
        "vcpkg_installed"
        ".vcpkg-root"
        "vcpkg-manifest-install.log"
    )
    
    local removed_count=0
    
    for file in "${vcpkg_files[@]}"; do
        local path="$BUILD_DIR/$file"
        if [[ -e "$path" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_info "Would remove: $file"
            else
                rm -rf "$path"
                log_debug "Removed: $file"
            fi
            ((removed_count++)) || true
        fi
    done
    
    # Check project root for vcpkg files too
    for file in "${vcpkg_files[@]}"; do
        local path="$PROJECT_ROOT/$file"
        if [[ -e "$path" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_info "Would remove: $file (from project root)"
            else
                rm -rf "$path"
                log_debug "Removed: $file (from project root)"
            fi
            ((removed_count++)) || true
        fi
    done
    
    log_debug "Cleared $removed_count vcpkg cache items"
}

# Reset compiler cache
reset_compiler_cache() {
    log_info "Resetting compiler cache..."
    
    # Clear ccache if available
    if command -v ccache >/dev/null 2>&1; then
        if [[ "$DRY_RUN" == true ]]; then
            log_info "Would clear ccache"
        else
            ccache -C 2>/dev/null || true
            log_debug "Cleared ccache"
        fi
    fi
    
    # Remove compile_commands.json
    local compile_commands="$BUILD_DIR/compile_commands.json"
    if [[ -f "$compile_commands" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_info "Would remove: compile_commands.json"
        else
            rm -f "$compile_commands"
            log_debug "Removed: compile_commands.json"
        fi
    fi
    
    # Remove .clangd cache if present
    local clangd_cache="$PROJECT_ROOT/.cache/clangd"
    if [[ -d "$clangd_cache" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_info "Would remove: .clangd cache"
        else
            rm -rf "$clangd_cache"
            log_debug "Removed: .clangd cache"
        fi
    fi
}

# Reconfigure project
reconfigure_project() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would reconfigure project with CMake"
        return 0
    fi
    
    if [[ "$SKIP_RECONFIGURE" == true ]]; then
        log_info "Skipping reconfiguration (--skip-reconfigure)"
        return 0
    fi
    
    log_info "Reconfiguring {{ project_name }} project..."
    
    # Ensure build directory exists
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Prepare CMake arguments
    local cmake_args=(
        -G "${GENERATOR:-Ninja}"
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE:-Release}"
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    )
    
    # Add vcpkg toolchain if available
    if [[ -n "${VCPKG_ROOT:-}" ]] && [[ -f "$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" ]]; then
        cmake_args+=(-DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake")
        log_debug "Using vcpkg toolchain: $VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake"
    elif [[ -d "$HOME/.vcpkg" ]] && [[ -f "$HOME/.vcpkg/scripts/buildsystems/vcpkg.cmake" ]]; then
        cmake_args+=(-DCMAKE_TOOLCHAIN_FILE="$HOME/.vcpkg/scripts/buildsystems/vcpkg.cmake")
        log_debug "Using vcpkg toolchain: $HOME/.vcpkg/scripts/buildsystems/vcpkg.cmake"
    fi
    
    # Add custom cmake args if provided
    if [[ -n "$CUSTOM_CMAKE_ARGS" ]]; then
        eval "cmake_args+=($CUSTOM_CMAKE_ARGS)"
        log_debug "Custom CMake args: $CUSTOM_CMAKE_ARGS"
    fi
    
    # Run CMake configuration
    log_debug "CMake command: cmake ${cmake_args[*]} $PROJECT_ROOT"
    
    if cmake "${cmake_args[@]}" "$PROJECT_ROOT"; then
        log_success "Project reconfigured successfully"
        
        # Show some useful information
        if [[ "${VERBOSE:-false}" == true ]]; then
            if [[ -f "compile_commands.json" ]]; then
                log_info "Generated compile_commands.json"
            fi
            
            if [[ -f "CMakeCache.txt" ]]; then
                log_info "Generated CMakeCache.txt"
                
                # Show some key cache variables
                local build_type
                build_type=$(grep "CMAKE_BUILD_TYPE:STRING=" CMakeCache.txt 2>/dev/null | cut -d= -f2 || echo "Unknown")
                log_debug "Build type: $build_type"
                
                local generator
                generator=$(grep "CMAKE_GENERATOR:INTERNAL=" CMakeCache.txt 2>/dev/null | cut -d= -f2 || echo "Unknown")
                log_debug "Generator: $generator"
            fi
        fi
    else
        log_error "Failed to reconfigure project"
        return 1
    fi
}

# Show status information
show_status() {
    if [[ "$QUIET" == true ]]; then
        return
    fi
    
    log_info "Cache Clear Summary:"
    echo "  Project: {{ project_name }}"
    echo "  Project Root: $PROJECT_ROOT"
    echo "  Build Directory: $BUILD_DIR"
    echo "  Mode: $([ "$DRY_RUN" == true ] && echo "Dry Run" || echo "Execute")"
    echo "  Reconfigure: $([ "$SKIP_RECONFIGURE" == true ] && echo "Skip" || echo "Yes")"
    
    if [[ "$DRY_RUN" != true ]]; then
        echo "  Build Type: ${BUILD_TYPE:-Release}"
        echo "  Generator: ${GENERATOR:-Ninja}"
    fi
    
    if [[ -n "${VCPKG_ROOT:-}" ]]; then
        echo "  vcpkg Root: $VCPKG_ROOT"
    fi
}

# Print usage information
print_usage() {
    cat << EOF
${BOLD}{{ project_name }} CMake Cache Clear Script${NC}
Clear CMake cache and reconfigure project from scratch

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}CLEAR OPTIONS:${NC}
    --all                   Clear everything and reconfigure (default)
    --cmake                 Clear only CMake cache files
    --vcpkg                 Clear only vcpkg cache
    --compiler              Clear only compiler cache (ccache, clangd)

${BOLD}CONFIGURATION OPTIONS:${NC}
    -t, --type TYPE         Build type for reconfiguration (Debug, Release, etc.)
    -g, --generator GEN     CMake generator (Ninja, "Unix Makefiles", etc.)
    --cmake-args "ARGS"     Additional CMake arguments for reconfiguration
    --skip-reconfigure      Clear cache but don't reconfigure

${BOLD}BEHAVIOR OPTIONS:${NC}
    -n, --dry-run           Show what would be cleared without actually clearing
    -v, --verbose           Enable verbose output with detailed information
    -q, --quiet             Suppress non-essential output
    --color                 Force colored output
    --no-color              Disable colored output

${BOLD}UTILITY OPTIONS:${NC}
    -h, --help              Show this help message

${BOLD}EXAMPLES:${NC}
    $0                              # Clear all cache and reconfigure
    $0 --dry-run                    # Show what would be cleared
    $0 --cmake --vcpkg              # Clear only CMake and vcpkg cache
    $0 --skip-reconfigure           # Clear cache but don't reconfigure
    $0 -t Debug -g "Unix Makefiles" # Clear and reconfigure with Debug/Make
    $0 --cmake-args "-DFOO=bar"     # Clear and reconfigure with custom args

${BOLD}WHAT GETS CLEARED:${NC}
    CMake:      CMakeCache.txt, CMakeFiles/, compile_commands.json, etc.
    vcpkg:      vcpkg_installed/, vcpkg-manifest-install.log, etc.
    Compiler:   ccache, .clangd cache, compilation database

${BOLD}NOTES:${NC}
    - This script preserves source code and project configuration files
    - Use --dry-run to preview what will be cleared
    - The script will auto-detect vcpkg and configure accordingly
    - Reconfiguration uses the same settings as the original build

EOF
}

# Default values
CLEAR_ALL=true
CLEAR_CMAKE=false
CLEAR_VCPKG=false
CLEAR_COMPILER=false
BUILD_TYPE=""
GENERATOR=""
CUSTOM_CMAKE_ARGS=""
SKIP_RECONFIGURE=false
DRY_RUN=false
VERBOSE=false
QUIET=false
FORCE_COLOR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CLEAR_ALL=true
            shift
            ;;
        --cmake)
            CLEAR_ALL=false
            CLEAR_CMAKE=true
            shift
            ;;
        --vcpkg)
            CLEAR_ALL=false
            CLEAR_VCPKG=true
            shift
            ;;
        --compiler)
            CLEAR_ALL=false
            CLEAR_COMPILER=true
            shift
            ;;
        -t|--type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -g|--generator)
            GENERATOR="$2"
            shift 2
            ;;
        --cmake-args)
            CUSTOM_CMAKE_ARGS="$2"
            shift 2
            ;;
        --skip-reconfigure)
            SKIP_RECONFIGURE=true
            shift
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
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Handle color output
if [[ "$FORCE_COLOR" == false ]] || [[ ! -t 1 ]] || [[ "$QUIET" == true ]]; then
    RED="" GREEN="" YELLOW="" BLUE="" PURPLE="" CYAN="" BOLD="" NC=""
fi

# Set individual clear flags if --all is true
if [[ "$CLEAR_ALL" == true ]]; then
    CLEAR_CMAKE=true
    CLEAR_VCPKG=true
    CLEAR_COMPILER=true
fi

# Main execution
main() {
    # Print header
    if [[ "$QUIET" != true ]]; then
        log_info "Starting {{ project_name }} cache clear..."
        echo
    fi
    
    show_status
    
    if [[ "$QUIET" != true ]]; then
        echo
    fi
    
    # Check if build directory exists
    if [[ ! -d "$BUILD_DIR" ]] && [[ "$DRY_RUN" != true ]]; then
        log_warning "Build directory does not exist: $BUILD_DIR"
        log_info "Creating build directory..."
        mkdir -p "$BUILD_DIR"
    fi
    
    # Execute clear functions
    if [[ "$CLEAR_CMAKE" == true ]]; then
        clear_cmake_cache
    fi
    
    if [[ "$CLEAR_VCPKG" == true ]]; then
        clear_vcpkg_cache
    fi
    
    if [[ "$CLEAR_COMPILER" == true ]]; then
        reset_compiler_cache
    fi
    
    # Reconfigure if requested
    if [[ "$SKIP_RECONFIGURE" != true ]]; then
        echo
        reconfigure_project
    fi
    
    # Final summary
    if [[ "$QUIET" != true ]]; then
        echo
        if [[ "$DRY_RUN" == true ]]; then
            log_success "Dry run completed - no cache was actually cleared"
        else
            log_success "{{ project_name }} cache clear completed!"
            if [[ "$SKIP_RECONFIGURE" != true ]]; then
                log_info "Project is ready for building"
            fi
        fi
    fi
}

# Run main function
main "$@" 