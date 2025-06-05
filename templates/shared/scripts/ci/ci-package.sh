#!/bin/bash

# {{ project_name }} CI Packaging Script
# Create distributable packages for various platforms and formats

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly BUILD_DIR="${PROJECT_ROOT}/build"
readonly PACKAGE_DIR="${BUILD_DIR}/packages"

# Colors for output (will be disabled in CI)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# CI Environment Detection
detect_ci_environment() {
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "github-actions"
    elif [[ -n "${GITLAB_CI:-}" ]]; then
        echo "gitlab-ci"
    elif [[ -n "${CI:-}" ]] || [[ -n "${CONTINUOUS_INTEGRATION:-}" ]]; then
        echo "generic-ci"
    else
        echo "local"
    fi
}

readonly CI_ENVIRONMENT=$(detect_ci_environment)

# Platform detection
readonly OS_TYPE="$(uname -s)"
readonly ARCH_TYPE="$(uname -m)"

# Disable colors in CI environments unless explicitly enabled
if [[ "$CI_ENVIRONMENT" != "local" ]] && [[ "${FORCE_COLOR:-false}" != "true" ]]; then
    RED="" GREEN="" YELLOW="" BLUE="" PURPLE="" CYAN="" BOLD="" NC=""
fi

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${VERBOSE:-false}" == true ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $*"
    fi
}

log_section() {
    echo -e "${CYAN}${BOLD}=== $* ===${NC}"
}

# Detect project version
detect_project_version() {
    local version="unknown"
    
    # Try to read version from various sources
    local version_sources=(
        "$PROJECT_ROOT/VERSION"
        "$PROJECT_ROOT/version.txt"
        "$PROJECT_ROOT/CMakeLists.txt"
        "$PROJECT_ROOT/vcpkg.json"
        "$PROJECT_ROOT/package.json"
    )
    
    for source in "${version_sources[@]}"; do
        if [[ -f "$source" ]]; then
            case "$(basename "$source")" in
                "VERSION"|"version.txt")
                    if [[ -s "$source" ]]; then
                        version=$(head -1 "$source" | tr -d '\n\r\t ')
                        break
                    fi
                    ;;
                "CMakeLists.txt")
                    version=$(grep -o 'VERSION [0-9]\+\.[0-9]\+\.[0-9]\+' "$source" | head -1 | cut -d' ' -f2)
                    if [[ -n "$version" ]]; then
                        break
                    fi
                    ;;
                "vcpkg.json")
                    if command -v jq >/dev/null 2>&1; then
                        local vcpkg_version
                        vcpkg_version=$(jq -r '.version // .version-string // empty' "$source" 2>/dev/null)
                        if [[ -n "$vcpkg_version" ]] && [[ "$vcpkg_version" != "null" ]]; then
                            version="$vcpkg_version"
                            break
                        fi
                    fi
                    ;;
                "package.json")
                    if command -v jq >/dev/null 2>&1; then
                        local npm_version
                        npm_version=$(jq -r '.version // empty' "$source" 2>/dev/null)
                        if [[ -n "$npm_version" ]] && [[ "$npm_version" != "null" ]]; then
                            version="$npm_version"
                            break
                        fi
                    fi
                    ;;
            esac
        fi
    done
    
    # Try git if no version file found
    if [[ "$version" == "unknown" ]] && command -v git >/dev/null 2>&1 && [[ -d "$PROJECT_ROOT/.git" ]]; then
        if git describe --tags --exact-match HEAD >/dev/null 2>&1; then
            version=$(git describe --tags --exact-match HEAD)
        elif git describe --tags >/dev/null 2>&1; then
            version=$(git describe --tags)
        else
            version="dev-$(git rev-parse --short HEAD)"
        fi
    fi
    
    # Use timestamp if still unknown
    if [[ "$version" == "unknown" ]]; then
        version="snapshot-$(date +%Y%m%d%H%M%S)"
    fi
    
    echo "$version"
}

# Get package name
get_package_name() {
    local name="unknown"
    
    # Try to get name from various sources
    if [[ -f "$PROJECT_ROOT/vcpkg.json" ]] && command -v jq >/dev/null 2>&1; then
        name=$(jq -r '.name // empty' "$PROJECT_ROOT/vcpkg.json" 2>/dev/null)
    fi
    
    if [[ -z "$name" ]] || [[ "$name" == "null" ]]; then
        name=$(basename "$PROJECT_ROOT")
    fi
    
    echo "$name"
}

# Check packaging prerequisites
check_packaging_tools() {
    log_section "Checking packaging tools"
    
    local required_tools=("cmake" "tar" "gzip")
    local optional_tools=()
    local missing_required=()
    local missing_optional=()
    
    # Add format-specific tools
    if [[ "${CREATE_DEB:-false}" == "true" ]]; then
        optional_tools+=("dpkg-deb" "fakeroot")
    fi
    
    if [[ "${CREATE_RPM:-false}" == "true" ]]; then
        optional_tools+=("rpmbuild")
    fi
    
    if [[ "${CREATE_ZIP:-true}" == "true" ]]; then
        optional_tools+=("zip")
    fi
    
    if [[ "${CREATE_APPIMAGE:-false}" == "true" ]]; then
        optional_tools+=("appimagetool")
    fi
    
    # Check required tools
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_required+=("$tool")
        else
            log_debug "Found required tool: $tool"
        fi
    done
    
    # Check optional tools
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_optional+=("$tool")
        else
            log_debug "Found optional tool: $tool"
        fi
    done
    
    # Report results
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_required[*]}"
        return 1
    fi
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_warning "Missing optional tools: ${missing_optional[*]}"
        log_info "Some package formats will be skipped"
    fi
    
    log_success "Packaging tools check completed"
    return 0
}

# Prepare package environment
prepare_package_environment() {
    log_section "Preparing package environment"
    
    # Clean and create package directory
    if [[ -d "$PACKAGE_DIR" ]] && [[ "${CLEAN_PACKAGES:-true}" == "true" ]]; then
        log_info "Cleaning existing packages..."
        rm -rf "$PACKAGE_DIR"
    fi
    
    mkdir -p "$PACKAGE_DIR"
    
    # Detect project info
    readonly PROJECT_NAME=$(get_package_name)
    readonly PROJECT_VERSION=$(detect_project_version)
    
    log_info "Project: $PROJECT_NAME"
    log_info "Version: $PROJECT_VERSION"
    log_info "Platform: $OS_TYPE ($ARCH_TYPE)"
    log_info "Package Directory: $PACKAGE_DIR"
    
    # Create package metadata
    cat > "$PACKAGE_DIR/package-info.txt" << EOF
Package Information
==================
Name: $PROJECT_NAME
Version: $PROJECT_VERSION
Platform: $OS_TYPE
Architecture: $ARCH_TYPE
Build Date: $(date)
Build Environment: $CI_ENVIRONMENT
EOF
    
    log_success "Package environment prepared"
}

# Install project to staging area
install_to_staging() {
    log_section "Installing to staging area"
    
    local staging_dir="$PACKAGE_DIR/staging"
    mkdir -p "$staging_dir"
    
    # Check if we have a build
    if [[ ! -d "$BUILD_DIR" ]] || [[ ! -f "$BUILD_DIR/CMakeCache.txt" ]]; then
        log_error "No build found. Run ci-build.sh first."
        return 1
    fi
    
    cd "$BUILD_DIR"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would install project to staging"
        return 0
    fi
    
    # Install to staging area
    local install_args=(
        --install .
        --prefix "$staging_dir"
        --config "${BUILD_TYPE:-Release}"
    )
    
    log_info "Installing project to staging area..."
    log_debug "Install command: cmake ${install_args[*]}"
    
    if cmake "${install_args[@]}"; then
        log_success "Project installed to staging area"
        
        # Show what was installed
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            log_info "Staging area contents:"
            find "$staging_dir" -type f | head -20
        fi
        
        return 0
    else
        log_error "Failed to install project to staging area"
        return 1
    fi
}

# Create source package
create_source_package() {
    if [[ "${CREATE_SOURCE:-true}" != "true" ]]; then
        return 0
    fi
    
    log_section "Creating source package"
    
    local source_package="$PACKAGE_DIR/${PROJECT_NAME}-${PROJECT_VERSION}-src.tar.gz"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would create source package: $source_package"
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Create temporary directory for source preparation
    local temp_dir
    temp_dir=$(mktemp -d)
    local source_dir="$temp_dir/${PROJECT_NAME}-${PROJECT_VERSION}"
    
    mkdir -p "$source_dir"
    
    # Copy source files (exclude build and package directories)
    log_info "Preparing source files..."
    
    # Use git if available for cleaner source
    if command -v git >/dev/null 2>&1 && [[ -d ".git" ]]; then
        git archive HEAD | tar -x -C "$source_dir"
    else
        # Fallback to rsync/cp with exclusions
        local exclude_patterns=(
            "build*"
            "packages"
            ".git*"
            "*.tmp"
            "*.temp"
            ".DS_Store"
            "Thumbs.db"
        )
        
        rsync -av \
            $(printf -- "--exclude=%s " "${exclude_patterns[@]}") \
            . "$source_dir/" 2>/dev/null || \
        cp -r . "$source_dir/"
    fi
    
    # Create tarball
    log_info "Creating source tarball..."
    cd "$temp_dir"
    
    if tar czf "$source_package" "${PROJECT_NAME}-${PROJECT_VERSION}"; then
        log_success "Source package created: $(basename "$source_package")"
        
        # Show package info
        local size
        size=$(du -h "$source_package" | cut -f1)
        log_info "Source package size: $size"
    else
        log_error "Failed to create source package"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    return 0
}

# Create binary package (tarball)
create_binary_package() {
    if [[ "${CREATE_BINARY:-true}" != "true" ]]; then
        return 0
    fi
    
    log_section "Creating binary package"
    
    local staging_dir="$PACKAGE_DIR/staging"
    if [[ ! -d "$staging_dir" ]]; then
        log_error "No staging area found. Install to staging first."
        return 1
    fi
    
    local binary_package="$PACKAGE_DIR/${PROJECT_NAME}-${PROJECT_VERSION}-${OS_TYPE,,}-${ARCH_TYPE}.tar.gz"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would create binary package: $binary_package"
        return 0
    fi
    
    cd "$PACKAGE_DIR"
    
    # Create binary tarball
    log_info "Creating binary tarball..."
    
    if tar czf "$binary_package" -C staging .; then
        log_success "Binary package created: $(basename "$binary_package")"
        
        # Show package info
        local size
        size=$(du -h "$binary_package" | cut -f1)
        log_info "Binary package size: $size"
        
        return 0
    else
        log_error "Failed to create binary package"
        return 1
    fi
}

# Create ZIP package
create_zip_package() {
    if [[ "${CREATE_ZIP:-true}" != "true" ]] || ! command -v zip >/dev/null 2>&1; then
        return 0
    fi
    
    log_section "Creating ZIP package"
    
    local staging_dir="$PACKAGE_DIR/staging"
    if [[ ! -d "$staging_dir" ]]; then
        log_error "No staging area found. Install to staging first."
        return 1
    fi
    
    local zip_package="$PACKAGE_DIR/${PROJECT_NAME}-${PROJECT_VERSION}-${OS_TYPE,,}-${ARCH_TYPE}.zip"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would create ZIP package: $zip_package"
        return 0
    fi
    
    cd "$staging_dir"
    
    log_info "Creating ZIP package..."
    
    if zip -r "$zip_package" .; then
        log_success "ZIP package created: $(basename "$zip_package")"
        
        # Show package info
        local size
        size=$(du -h "$zip_package" | cut -f1)
        log_info "ZIP package size: $size"
        
        return 0
    else
        log_error "Failed to create ZIP package"
        return 1
    fi
}

# Create DEB package (Linux only)
create_deb_package() {
    if [[ "${CREATE_DEB:-false}" != "true" ]] || [[ "$OS_TYPE" != "Linux" ]] || ! command -v dpkg-deb >/dev/null 2>&1; then
        return 0
    fi
    
    log_section "Creating DEB package"
    
    local staging_dir="$PACKAGE_DIR/staging"
    if [[ ! -d "$staging_dir" ]]; then
        log_error "No staging area found. Install to staging first."
        return 1
    fi
    
    local deb_dir="$PACKAGE_DIR/deb"
    local deb_package="$PACKAGE_DIR/${PROJECT_NAME}_${PROJECT_VERSION}_${ARCH_TYPE}.deb"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would create DEB package: $deb_package"
        return 0
    fi
    
    # Prepare DEB structure
    mkdir -p "$deb_dir/DEBIAN"
    mkdir -p "$deb_dir/usr"
    
    # Copy files
    cp -r "$staging_dir"/* "$deb_dir/usr/"
    
    # Create control file
    cat > "$deb_dir/DEBIAN/control" << EOF
Package: $PROJECT_NAME
Version: $PROJECT_VERSION
Section: devel
Priority: optional
Architecture: $ARCH_TYPE
Maintainer: {{ project_name }} Team <maintainer@example.com>
Description: {{ project_name }} - Modern C++20 Application
 A modern C++20 application built with advanced features and best practices.
 .
 This package contains the compiled binaries and necessary files.
EOF
    
    log_info "Creating DEB package..."
    
    if dpkg-deb --build "$deb_dir" "$deb_package"; then
        log_success "DEB package created: $(basename "$deb_package")"
        
        # Show package info
        local size
        size=$(du -h "$deb_package" | cut -f1)
        log_info "DEB package size: $size"
        
        return 0
    else
        log_error "Failed to create DEB package"
        return 1
    fi
}

# Create checksums and signatures
create_checksums() {
    if [[ "${CREATE_CHECKSUMS:-true}" != "true" ]]; then
        return 0
    fi
    
    log_section "Creating checksums"
    
    cd "$PACKAGE_DIR"
    
    local checksum_file="$PACKAGE_DIR/checksums.txt"
    : > "$checksum_file"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would create checksums for packages"
        return 0
    fi
    
    log_info "Generating checksums..."
    
    # Find all package files
    local package_files=()
    while IFS= read -r -d '' file; do
        package_files+=("$file")
    done < <(find . -maxdepth 1 -name "*.tar.gz" -o -name "*.zip" -o -name "*.deb" -o -name "*.rpm" -print0)
    
    if [[ ${#package_files[@]} -eq 0 ]]; then
        log_warning "No package files found for checksums"
        return 0
    fi
    
    # Generate different types of checksums
    for file in "${package_files[@]}"; do
        local filename=$(basename "$file")
        
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum "$filename" >> "$checksum_file"
        elif command -v shasum >/dev/null 2>&1; then
            shasum -a 256 "$filename" >> "$checksum_file"
        fi
        
        if command -v md5sum >/dev/null 2>&1; then
            md5sum "$filename" >> "${checksum_file%.txt}.md5"
        elif command -v md5 >/dev/null 2>&1; then
            md5 "$filename" >> "${checksum_file%.txt}.md5"
        fi
    done
    
    if [[ -s "$checksum_file" ]]; then
        log_success "Checksums created: $(basename "$checksum_file")"
    else
        log_warning "No checksums generated"
    fi
    
    return 0
}

# Generate package summary
generate_package_summary() {
    log_section "Package Summary"
    
    cd "$PACKAGE_DIR"
    
    local summary_file="$PACKAGE_DIR/package-summary.md"
    
    {
        echo "# {{ project_name }} Package Summary"
        echo
        echo "**Package Date:** $(date)"
        echo "**Project:** $PROJECT_NAME"
        echo "**Version:** $PROJECT_VERSION"
        echo "**Platform:** $OS_TYPE ($ARCH_TYPE)"
        echo "**Build Environment:** $CI_ENVIRONMENT"
        echo
        echo "## Generated Packages"
        echo
        
        # List all package files
        local total_size=0
        while IFS= read -r -d '' file; do
            local filename=$(basename "$file")
            local size_bytes
            size_bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
            local size_human
            size_human=$(du -h "$file" | cut -f1)
            
            ((total_size += size_bytes))
            
            echo "- **$filename** ($size_human)"
            
        done < <(find . -maxdepth 1 -name "*.tar.gz" -o -name "*.zip" -o -name "*.deb" -o -name "*.rpm" -print0)
        
        echo
        echo "**Total Size:** $(numfmt --to=iec-i --suffix=B $total_size 2>/dev/null || echo "$total_size bytes")"
        echo
        
        if [[ -f "checksums.txt" ]]; then
            echo "## Checksums (SHA256)"
            echo
            echo "```"
            cat checksums.txt
            echo "```"
            echo
        fi
        
        echo "## Installation"
        echo
        echo "### Binary Package (Linux/macOS)"
        echo "```bash"
        echo "tar -xzf ${PROJECT_NAME}-${PROJECT_VERSION}-${OS_TYPE,,}-${ARCH_TYPE}.tar.gz"
        echo "```"
        echo
        
        if [[ -f "${PROJECT_NAME}_${PROJECT_VERSION}_${ARCH_TYPE}.deb" ]]; then
            echo "### DEB Package (Debian/Ubuntu)"
            echo "```bash"
            echo "sudo dpkg -i ${PROJECT_NAME}_${PROJECT_VERSION}_${ARCH_TYPE}.deb"
            echo "```"
            echo
        fi
        
        echo "### Source Package"
        echo "```bash"
        echo "tar -xzf ${PROJECT_NAME}-${PROJECT_VERSION}-src.tar.gz"
        echo "cd ${PROJECT_NAME}-${PROJECT_VERSION}"
        echo "mkdir build && cd build"
        echo "cmake .."
        echo "cmake --build ."
        echo "```"
        
    } > "$summary_file"
    
    log_info "Package summary: $summary_file"
    
    # Show quick summary
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo
        cat "$summary_file"
    else
        echo
        log_info "Packages created in: $PACKAGE_DIR"
        find . -maxdepth 1 -name "*.tar.gz" -o -name "*.zip" -o -name "*.deb" | while read -r file; do
            local size
            size=$(du -h "$file" | cut -f1)
            log_info "  $(basename "$file") ($size)"
        done
    fi
}

# Print usage information
print_usage() {
    cat << EOF
${BOLD}{{ project_name }} CI Packaging Script${NC}
Create distributable packages for various platforms and formats

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}PACKAGE TYPES:${NC}
    --create-source             Create source code package (default: on)
    --create-binary             Create binary package (default: on)
    --create-zip                Create ZIP package (default: on)
    --create-deb                Create DEB package (Linux only)
    --create-rpm                Create RPM package (Linux only)
    --create-appimage           Create AppImage (Linux only)

${BOLD}PACKAGE OPTIONS:${NC}
    --build-type TYPE           Build type to package (default: Release)
    --clean-packages            Clean existing packages before creating new ones
    --no-checksums              Skip checksum generation
    --package-dir DIR           Directory for packages (default: build/packages)

${BOLD}CONTENT OPTIONS:${NC}
    --include-docs              Include documentation in packages
    --include-examples          Include example files
    --strip-binaries            Strip debug symbols from binaries

${BOLD}OUTPUT OPTIONS:${NC}
    --force-color               Force colored output in CI

${BOLD}BEHAVIOR OPTIONS:${NC}
    -n, --dry-run               Show what would be done without executing
    -v, --verbose               Enable verbose output
    -q, --quiet                 Suppress non-essential output

${BOLD}UTILITY OPTIONS:${NC}
    -h, --help                  Show this help message

${BOLD}EXAMPLES:${NC}
    $0                                  # Create all default packages
    $0 --create-deb --create-rpm        # Only create Linux packages
    $0 --no-checksums --dry-run         # Preview without checksums
    $0 --strip-binaries --include-docs  # Optimized package with docs

${BOLD}PACKAGE FORMATS:${NC}
    - Source (.tar.gz)          # Source code archive
    - Binary (.tar.gz)          # Compiled binaries
    - ZIP (.zip)                # Windows-friendly archive
    - DEB (.deb)                # Debian/Ubuntu package
    - RPM (.rpm)                # RedHat/SUSE package
    - AppImage (.AppImage)      # Portable Linux application

${BOLD}OUTPUT:${NC}
    Packages are created in build/packages/ with:
    - Package files in various formats
    - checksums.txt with SHA256 hashes
    - package-summary.md with overview
    - package-info.txt with metadata

EOF
}

# Default values
CREATE_SOURCE="true"
CREATE_BINARY="true"
CREATE_ZIP="true"
CREATE_DEB="false"
CREATE_RPM="false"
CREATE_APPIMAGE="false"
BUILD_TYPE="Release"
CLEAN_PACKAGES="true"
CREATE_CHECKSUMS="true"
PACKAGE_DIR_CUSTOM=""
INCLUDE_DOCS="false"
INCLUDE_EXAMPLES="false"
STRIP_BINARIES="false"
FORCE_COLOR="false"
DRY_RUN="false"
VERBOSE="false"
QUIET="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --create-source)
            CREATE_SOURCE="true"
            shift
            ;;
        --create-binary)
            CREATE_BINARY="true"
            shift
            ;;
        --create-zip)
            CREATE_ZIP="true"
            shift
            ;;
        --create-deb)
            CREATE_DEB="true"
            shift
            ;;
        --create-rpm)
            CREATE_RPM="true"
            shift
            ;;
        --create-appimage)
            CREATE_APPIMAGE="true"
            shift
            ;;
        --build-type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        --clean-packages)
            CLEAN_PACKAGES="true"
            shift
            ;;
        --no-checksums)
            CREATE_CHECKSUMS="false"
            shift
            ;;
        --package-dir)
            PACKAGE_DIR_CUSTOM="$2"
            shift 2
            ;;
        --include-docs)
            INCLUDE_DOCS="true"
            shift
            ;;
        --include-examples)
            INCLUDE_EXAMPLES="true"
            shift
            ;;
        --strip-binaries)
            STRIP_BINARIES="true"
            shift
            ;;
        --force-color)
            FORCE_COLOR="true"
            shift
            ;;
        -n|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -q|--quiet)
            QUIET="true"
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

# Override package directory if specified
if [[ -n "$PACKAGE_DIR_CUSTOM" ]]; then
    PACKAGE_DIR="$PACKAGE_DIR_CUSTOM"
fi

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    # Print header
    if [[ "$QUIET" != "true" ]]; then
        log_info "Starting {{ project_name }} packaging..."
        log_info "Environment: $CI_ENVIRONMENT"
        echo
    fi
    
    # Execute packaging pipeline
    local exit_code=0
    
    check_packaging_tools || exit_code=1
    [[ $exit_code -eq 0 ]] && prepare_package_environment || exit_code=1
    [[ $exit_code -eq 0 ]] && install_to_staging || exit_code=1
    [[ $exit_code -eq 0 ]] && create_source_package || exit_code=1
    [[ $exit_code -eq 0 ]] && create_binary_package || exit_code=1
    [[ $exit_code -eq 0 ]] && create_zip_package || exit_code=1
    [[ $exit_code -eq 0 ]] && create_deb_package || exit_code=1
    [[ $exit_code -eq 0 ]] && create_checksums || exit_code=1
    
    # Always generate summary
    generate_package_summary
    
    # Final status
    if [[ $exit_code -eq 0 ]]; then
        if [[ "$QUIET" != "true" ]]; then
            echo
            log_success "{{ project_name }} packaging completed successfully!"
        fi
    else
        if [[ "$QUIET" != "true" ]]; then
            echo
            log_error "{{ project_name }} packaging failed!"
        fi
    fi
    
    exit $exit_code
}

# Run main function
main "$@"