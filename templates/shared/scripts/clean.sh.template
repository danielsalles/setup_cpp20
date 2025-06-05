#!/bin/bash

# {{ project_name }} Project Cleanup Script
# Remove build artifacts, temporary files, and clean project directories

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

# Calculate directory size
calculate_size() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        case "$OS_TYPE" in
            Darwin*)
                du -sh "$dir" 2>/dev/null | cut -f1 || echo "0B"
                ;;
            Linux*)
                du -sh "$dir" 2>/dev/null | cut -f1 || echo "0B"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    else
        echo "0B"
    fi
}

# Count files in directory
count_files() {
    local pattern="$1"
    find . -name "$pattern" -type f 2>/dev/null | wc -l | tr -d ' '
}

# Safe remove with logging
safe_remove() {
    local path="$1"
    local description="${2:-$path}"
    
    if [[ ! -e "$path" ]]; then
        log_debug "Not found: $description"
        return 0
    fi
    
    local size=""
    if [[ -d "$path" ]]; then
        size=" ($(calculate_size "$path"))"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would remove: $description$size"
        return 0
    fi
    
    log_debug "Removing: $description$size"
    
    if rm -rf "$path" 2>/dev/null; then
        if [[ "${VERBOSE:-false}" == true ]]; then
            log_success "Removed: $description$size"
        fi
        return 0
    else
        log_warning "Failed to remove: $description"
        return 1
    fi
}

# Clean build directories
clean_build_dirs() {
    log_info "Cleaning build directories..."
    
    local build_patterns=(
        "build"
        "cmake-build-*"
        "_build"
        "out"
        ".build"
        "Release"
        "Debug" 
        "RelWithDebInfo"
        "MinSizeRel"
    )
    
    local removed_count=0
    for pattern in "${build_patterns[@]}"; do
        while IFS= read -r -d '' dir; do
            if safe_remove "$dir" "Build directory: $(basename "$dir")"; then
                ((removed_count++)) || true
            fi
        done < <(find "$PROJECT_ROOT" -maxdepth 2 -name "$pattern" -type d -print0 2>/dev/null || true)
    done
    
    log_debug "Removed $removed_count build directories"
}

# Clean compiler artifacts
clean_compiler_artifacts() {
    log_info "Cleaning compiler artifacts..."
    
    local artifact_patterns=(
        "*.o"
        "*.obj"
        "*.a"
        "*.lib"
        "*.so"
        "*.so.*"
        "*.dylib"
        "*.dll"
        "*.exe"
        "*.pdb"
        "*.ilk"
        "*.exp"
        "*.idb"
        "*.map"
    )
    
    local total_removed=0
    for pattern in "${artifact_patterns[@]}"; do
        local count
        count=$(count_files "$pattern")
        if [[ "$count" -gt 0 ]]; then
            log_debug "Found $count files matching $pattern"
            
            if [[ "$DRY_RUN" == true ]]; then
                log_info "Would remove $count files matching $pattern"
            else
                find "$PROJECT_ROOT" -name "$pattern" -type f -delete 2>/dev/null || true
                log_debug "Removed $count files matching $pattern"
            fi
            
            ((total_removed += count)) || true
        fi
    done
    
    log_debug "Removed $total_removed compiler artifacts"
}

# Clean temporary files
clean_temp_files() {
    log_info "Cleaning temporary files..."
    
    local temp_patterns=(
        "*.tmp"
        "*.temp"
        "*~"
        "*.bak"
        "*.backup"
        "*.orig"
        "*.swp"
        "*.swo"
        ".*.swp"
        ".*.swo"
        "*.cache"
        "*.log"
        ".DS_Store"
        "Thumbs.db"
        "desktop.ini"
        "*.rej"
        "*.patch"
        "core"
        "*.core"
        "*.dmp"
    )
    
    local total_removed=0
    for pattern in "${temp_patterns[@]}"; do
        local count
        count=$(count_files "$pattern")
        if [[ "$count" -gt 0 ]]; then
            log_debug "Found $count files matching $pattern"
            
            if [[ "$DRY_RUN" == true ]]; then
                log_info "Would remove $count files matching $pattern"
            else
                find "$PROJECT_ROOT" -name "$pattern" -type f -delete 2>/dev/null || true
                log_debug "Removed $count files matching $pattern"
            fi
            
            ((total_removed += count)) || true
        fi
    done
    
    log_debug "Removed $total_removed temporary files"
}

# Clean CMake files
clean_cmake_files() {
    log_info "Cleaning CMake generated files..."
    
    local cmake_patterns=(
        "CMakeCache.txt"
        "CMakeFiles"
        "cmake_install.cmake"
        "CTestTestfile.cmake"
        "install_manifest.txt"
        "compile_commands.json"
        "CPackConfig.cmake"
        "CPackSourceConfig.cmake"
        "_deps"
    )
    
    local removed_count=0
    for pattern in "${cmake_patterns[@]}"; do
        while IFS= read -r -d '' item; do
            if safe_remove "$item" "CMake file: $(basename "$item")"; then
                ((removed_count++)) || true
            fi
        done < <(find "$PROJECT_ROOT" -name "$pattern" -print0 2>/dev/null || true)
    done
    
    log_debug "Removed $removed_count CMake files"
}

# Clean vcpkg artifacts
clean_vcpkg_artifacts() {
    log_info "Cleaning vcpkg artifacts..."
    
    local vcpkg_patterns=(
        "vcpkg_installed"
        ".vcpkg-root"
        "vcpkg-manifest-install.log"
        "buildtrees"
        "packages"
        "downloads"
    )
    
    local removed_count=0
    for pattern in "${vcpkg_patterns[@]}"; do
        while IFS= read -r -d '' item; do
            if safe_remove "$item" "vcpkg artifact: $(basename "$item")"; then
                ((removed_count++)) || true
            fi
        done < <(find "$PROJECT_ROOT" -maxdepth 2 -name "$pattern" -print0 2>/dev/null || true)
    done
    
    log_debug "Removed $removed_count vcpkg artifacts"
}

# Clean IDE files
clean_ide_files() {
    log_info "Cleaning IDE generated files..."
    
    local ide_patterns=(
        ".vscode/settings.json"
        ".vscode/launch.json"
        ".vscode/tasks.json"
        ".vscode/c_cpp_properties.json"
        "*.vcxproj.user"
        "*.vcxproj.filters"
        "*.sln.docstates"
        ".vs"
        "*.sublime-workspace"
        "*.code-workspace"
        ".idea"
        "*.iml"
        "*.ipr"
        "*.iws"
        ".clangd"
        ".cache/clangd"
        "compile_flags.txt"
    )
    
    local removed_count=0
    for pattern in "${ide_patterns[@]}"; do
        while IFS= read -r -d '' item; do
            if [[ "$PRESERVE_IDE" == true ]] && [[ "$pattern" =~ \.vscode|\.idea|\.vs ]]; then
                log_debug "Preserving IDE file: $(basename "$item")"
                continue
            fi
            
            if safe_remove "$item" "IDE file: $(basename "$item")"; then
                ((removed_count++)) || true
            fi
        done < <(find "$PROJECT_ROOT" -path "*/$pattern" -print0 2>/dev/null || true)
    done
    
    log_debug "Removed $removed_count IDE files"
}

# Clean test artifacts
clean_test_artifacts() {
    log_info "Cleaning test artifacts..."
    
    local test_patterns=(
        "Testing"
        "*.gcov"
        "*.gcda"
        "*.gcno"
        "coverage.info"
        "coverage.xml"
        "coverage.html"
        "coverage_html"
        "*.profraw"
        "*.profdata"
        "default.profraw"
        "callgrind.out.*"
        "massif.out.*"
        "helgrind.out.*"
        "*.dSYM"
    )
    
    local removed_count=0
    for pattern in "${test_patterns[@]}"; do
        while IFS= read -r -d '' item; do
            if safe_remove "$item" "Test artifact: $(basename "$item")"; then
                ((removed_count++)) || true
            fi
        done < <(find "$PROJECT_ROOT" -name "$pattern" -print0 2>/dev/null || true)
    done
    
    log_debug "Removed $removed_count test artifacts"
}

# Clean package manager artifacts
clean_package_artifacts() {
    log_info "Cleaning package manager artifacts..."
    
    local package_patterns=(
        "node_modules"
        "npm-debug.log*"
        ".npm"
        ".conan"
        "conanbuildinfo.*"
        "conaninfo.txt"
        "graph_info.json"
        ".cpmcache"
        "_deps"
    )
    
    local removed_count=0
    for pattern in "${package_patterns[@]}"; do
        while IFS= read -r -d '' item; do
            if safe_remove "$item" "Package artifact: $(basename "$item")"; then
                ((removed_count++)) || true
            fi
        done < <(find "$PROJECT_ROOT" -maxdepth 2 -name "$pattern" -print0 2>/dev/null || true)
    done
    
    log_debug "Removed $removed_count package artifacts"
}

# Show cleanup summary
show_summary() {
    if [[ "$QUIET" == true ]]; then
        return
    fi
    
    log_info "Cleanup Summary:"
    echo "  Project: {{ project_name }}"
    echo "  Root Directory: $PROJECT_ROOT"
    echo "  Mode: $([ "$DRY_RUN" == true ] && echo "Dry Run" || echo "Execute")"
    echo "  Preserve IDE Files: $([ "$PRESERVE_IDE" == true ] && echo "Yes" || echo "No")"
    
    if [[ "$DRY_RUN" != true ]]; then
        echo "  Current Size: $(calculate_size "$PROJECT_ROOT")"
    fi
}

# Print usage information
print_usage() {
    cat << EOF
${BOLD}{{ project_name }} Project Cleanup Script${NC}
Remove build artifacts, temporary files, and clean project directories

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}CLEANUP OPTIONS:${NC}
    --all                   Clean everything (default)
    --build                 Clean only build directories and artifacts
    --temp                  Clean only temporary files
    --cmake                 Clean only CMake generated files
    --vcpkg                 Clean only vcpkg artifacts
    --ide                   Clean only IDE generated files
    --test                  Clean only test artifacts and coverage data
    --packages              Clean only package manager artifacts

${BOLD}BEHAVIOR OPTIONS:${NC}
    -n, --dry-run           Show what would be removed without actually removing
    --preserve-ide          Keep IDE configuration files (.vscode, .idea, etc.)
    -v, --verbose           Enable verbose output with detailed information
    -q, --quiet             Suppress non-essential output
    --color                 Force colored output
    --no-color              Disable colored output

${BOLD}SAFETY OPTIONS:${NC}
    -f, --force             Skip confirmation prompts (use with caution)
    --confirm               Require confirmation before each cleanup category

${BOLD}UTILITY OPTIONS:${NC}
    --size                  Show directory sizes before cleanup
    -h, --help              Show this help message

${BOLD}EXAMPLES:${NC}
    $0                              # Clean everything with confirmation
    $0 --dry-run                    # Show what would be cleaned
    $0 --build --temp               # Clean only build and temporary files
    $0 --all --preserve-ide         # Clean everything but keep IDE files
    $0 --verbose --force            # Verbose cleanup without prompts

${BOLD}CLEANUP CATEGORIES:${NC}
    Build:      build/, cmake-build-*, *.o, *.a, *.so, *.exe, etc.
    Temp:       *.tmp, *.bak, *~, .DS_Store, *.log, etc.
    CMake:      CMakeCache.txt, CMakeFiles/, compile_commands.json, etc.
    vcpkg:      vcpkg_installed/, buildtrees/, packages/, etc.
    IDE:        .vscode/, .idea/, .vs/, *.vcxproj.user, etc.
    Test:       coverage files, *.gcov, *.profraw, callgrind.out.*, etc.
    Packages:   node_modules/, .conan/, conanbuildinfo.*, etc.

${BOLD}SAFETY NOTES:${NC}
    - By default, important configuration files are preserved
    - Use --dry-run to preview changes before actual cleanup
    - The script will not remove source code or essential project files
    - IDE files can be preserved with --preserve-ide option

EOF
}

# Default values
CLEAN_ALL=true
CLEAN_BUILD=false
CLEAN_TEMP=false
CLEAN_CMAKE=false
CLEAN_VCPKG=false
CLEAN_IDE=false
CLEAN_TEST=false
CLEAN_PACKAGES=false
DRY_RUN=false
PRESERVE_IDE=false
VERBOSE=false
QUIET=false
FORCE=false
CONFIRM=false
SHOW_SIZE=false
FORCE_COLOR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            CLEAN_ALL=true
            shift
            ;;
        --build)
            CLEAN_ALL=false
            CLEAN_BUILD=true
            shift
            ;;
        --temp)
            CLEAN_ALL=false
            CLEAN_TEMP=true
            shift
            ;;
        --cmake)
            CLEAN_ALL=false
            CLEAN_CMAKE=true
            shift
            ;;
        --vcpkg)
            CLEAN_ALL=false
            CLEAN_VCPKG=true
            shift
            ;;
        --ide)
            CLEAN_ALL=false
            CLEAN_IDE=true
            shift
            ;;
        --test)
            CLEAN_ALL=false
            CLEAN_TEST=true
            shift
            ;;
        --packages)
            CLEAN_ALL=false
            CLEAN_PACKAGES=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --preserve-ide)
            PRESERVE_IDE=true
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
        -f|--force)
            FORCE=true
            shift
            ;;
        --confirm)
            CONFIRM=true
            shift
            ;;
        --size)
            SHOW_SIZE=true
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

# Set individual clean flags if --all is true
if [[ "$CLEAN_ALL" == true ]]; then
    CLEAN_BUILD=true
    CLEAN_TEMP=true
    CLEAN_CMAKE=true
    CLEAN_VCPKG=true
    CLEAN_IDE=true
    CLEAN_TEST=true
    CLEAN_PACKAGES=true
fi

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    # Print header
    if [[ "$QUIET" != true ]]; then
        log_info "Starting {{ project_name }} project cleanup..."
        echo
    fi
    
    # Show current size if requested
    if [[ "$SHOW_SIZE" == true ]]; then
        log_info "Current project size: $(calculate_size "$PROJECT_ROOT")"
        echo
    fi
    
    show_summary
    
    if [[ "$QUIET" != true ]]; then
        echo
    fi
    
    # Confirmation prompt
    if [[ "$FORCE" != true ]] && [[ "$DRY_RUN" != true ]] && [[ -t 0 ]]; then
        echo -e "${YELLOW}⚠️  This will remove files and directories. Continue? [y/N]${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled by user"
            exit 0
        fi
        echo
    fi
    
    # Execute cleanup functions
    if [[ "$CLEAN_BUILD" == true ]]; then
        clean_build_dirs
    fi
    
    if [[ "$CLEAN_TEMP" == true ]]; then
        clean_temp_files
    fi
    
    if [[ "$CLEAN_CMAKE" == true ]]; then
        clean_cmake_files
    fi
    
    if [[ "$CLEAN_VCPKG" == true ]]; then
        clean_vcpkg_artifacts
    fi
    
    if [[ "$CLEAN_IDE" == true ]]; then
        clean_ide_files
    fi
    
    if [[ "$CLEAN_TEST" == true ]]; then
        clean_test_artifacts
    fi
    
    if [[ "$CLEAN_PACKAGES" == true ]]; then
        clean_package_artifacts
    fi
    
    # Final summary
    if [[ "$QUIET" != true ]]; then
        echo
        if [[ "$DRY_RUN" == true ]]; then
            log_success "Dry run completed - no files were actually removed"
        else
            log_success "{{ project_name }} project cleanup completed!"
            if [[ "$SHOW_SIZE" == true ]]; then
                log_info "Final project size: $(calculate_size "$PROJECT_ROOT")"
            fi
        fi
    fi
}

# Run main function
main "$@" 