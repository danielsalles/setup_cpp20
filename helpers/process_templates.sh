#!/bin/bash

# Template Processing Wrapper Script
# This script provides a convenient interface to the Python template processor

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_PROCESSOR="$SCRIPT_DIR/template_processor.py"

# Default values
TEMPLATES_DIR="$PROJECT_ROOT/templates"
OUTPUT_DIR="."
PROJECT_TYPE=""
PROJECT_NAME=""
CONFIG_FILE=""
AUTHOR=""
VERSION=""
DESCRIPTION=""
NO_SHARED=false
VERBOSE=false

# Repository configuration for remote access
REPO_BASE="https://raw.githubusercontent.com/danielsalles/setup_cpp20/main"
TEMPLATES_BASE="$REPO_BASE/templates"

# Local file paths (will be used if available, or downloaded if not)
TEMPLATE_PROCESSOR="$SCRIPT_DIR/template_processor.py"
LOCAL_TEMPLATES_DIR="$PROJECT_ROOT/templates"

# Temporary directory for downloads
TEMP_DIR=""

# Cleanup function
cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Default values - updated to use detection
TEMPLATES_DIR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] PROJECT_TYPE PROJECT_NAME

Process C++20 project templates using Jinja2

ARGUMENTS:
    PROJECT_TYPE    Type of project (console, library)
    PROJECT_NAME    Name of the project

OPTIONS:
    -o, --output DIR        Output directory (default: current directory)
    -c, --config FILE       JSON configuration file with template variables
    -t, --templates DIR     Templates directory (default: auto-detect or download)
    --author NAME           Project author name
    --version VERSION       Project version (e.g., 1.0.0)
    --description TEXT      Project description
    --no-shared             Do not copy shared files (cmake modules, scripts)
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    $0 console MyProject
    $0 library MyLibrary --author "John Doe" --version "2.0.0"
    $0 console TestApp --output ./projects --config project.json
    $0 library NetworkLib --description "A modern C++20 networking library"

REQUIREMENTS:
    - Python 3.6+ with Jinja2 installed
    - Template files in the templates directory

To install Jinja2:
    pip install jinja2

EOF
}

# Function to check if Python and Jinja2 are available
check_dependencies() {
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed"
        exit 1
    fi
    
    if ! python3 -c "import jinja2" 2>/dev/null; then
        print_error "Jinja2 is required but not installed"
        print_info "Install it with: pip install jinja2"
        exit 1
    fi
    
    # Check if we have local files or need to download them
    if [[ -f "$TEMPLATE_PROCESSOR" && -d "$LOCAL_TEMPLATES_DIR" ]]; then
        print_info "Using local template system"
        TEMPLATES_DIR="$LOCAL_TEMPLATES_DIR"
        USE_LOCAL=true
    else
        print_info "Local template system not found, downloading from repository"
        USE_LOCAL=false
        download_template_system
    fi
}

# Function to download template system when not available locally
download_template_system() {
    print_info "Downloading template processing system..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    
    # Download template processor first
    print_info "Downloading template_processor.py..."
    if ! curl -fsSL "$REPO_BASE/helpers/template_processor.py" -o "$TEMP_DIR/template_processor.py"; then
        print_error "Failed to download template processor"
        exit 1
    fi
    
    # Update the template processor path to use temp directory
    TEMPLATE_PROCESSOR="$TEMP_DIR/template_processor.py"
    
    # Try to download entire repository as ZIP (more robust)
    print_info "Downloading complete template system from repository..."
    
    local repo_zip="$TEMP_DIR/setup_cpp20.zip"
    local extract_dir="$TEMP_DIR/extract"
    
    # Download repository ZIP
    if curl -fsSL "https://github.com/danielsalles/setup_cpp20/archive/main.zip" -o "$repo_zip" 2>/dev/null; then
        print_info "Repository archive downloaded successfully"
        
        # Extract ZIP file
        print_info "Extracting templates..."
        mkdir -p "$extract_dir"
        
        if command -v unzip >/dev/null 2>&1; then
            if unzip -q "$repo_zip" -d "$extract_dir" 2>/dev/null; then
                # Check if templates directory exists in extracted content
                if [[ -d "$extract_dir/setup_cpp20-main/templates" ]]; then
                    TEMPLATES_DIR="$extract_dir/setup_cpp20-main/templates"
                    print_success "Template system downloaded and extracted successfully"
                    
                    # Cleanup ZIP file
                    rm -f "$repo_zip"
                    return 0
                else
                    print_warning "Templates directory not found in archive"
                fi
            else
                print_warning "Failed to extract repository archive"
            fi
        else
            print_warning "unzip command not available"
        fi
        
        # Cleanup failed ZIP
        rm -f "$repo_zip"
    else
        print_warning "Failed to download repository archive"
    fi
    
    # Fallback: download templates individually
    print_info "Falling back to individual file downloads..."
    download_templates_individually
}

# Fallback function for individual file downloads
download_templates_individually() {
    print_info "Downloading templates individually..."
    
    # Create templates directory in temp
    mkdir -p "$TEMP_DIR/templates"
    TEMPLATES_DIR="$TEMP_DIR/templates"
    
    # Download console templates
    download_template_files "console"
    
    # Download library templates
    download_template_files "library"
    
    # Download shared templates
    download_shared_templates
    
    print_success "Template system downloaded individually"
}

# Function to download template files for a specific project type
download_template_files() {
    local project_type="$1"
    local template_dir="$TEMPLATES_DIR/$project_type"
    
    print_info "Downloading $project_type templates..."
    mkdir -p "$template_dir"
    
    # Download main project files for the template type
    local base_url="$TEMPLATES_BASE/$project_type"
    
    # Common files for both console and library
    local files=(
        "CMakeLists.txt.template"
        ".gitignore.template"
        "README.md.template"
        "vcpkg.json.template"
    )
    
    # Add type-specific files
    case "$project_type" in
        "console")
            files+=("src/main.cpp.template")
            ;;
        "library")
            files+=("src/library.cpp.template" "include/library.hpp.template")
            ;;
    esac
    
    for file in "${files[@]}"; do
        local dest_file="$template_dir/$file"
        mkdir -p "$(dirname "$dest_file")"
        
        if ! curl -fsSL "$base_url/$file" -o "$dest_file" 2>/dev/null; then
            print_warning "Could not download $file, skipping..."
        fi
    done
}

# Function to download shared templates
download_shared_templates() {
    print_info "Downloading shared templates..."
    
    local shared_dir="$TEMPLATES_DIR/shared"
    mkdir -p "$shared_dir"
    
    # Download critical shared files
    local shared_files=(
        "cmake/CompilerWarnings.cmake.template"
        "cmake/VcpkgHelpers.cmake.template"
        "scripts/build.sh.template"
        "scripts/test.sh.template"
        ".clang-format.template"
        "Doxyfile.template"
    )
    
    for file in "${shared_files[@]}"; do
        local dest_file="$shared_dir/$file"
        mkdir -p "$(dirname "$dest_file")"
        
        if ! curl -fsSL "$TEMPLATES_BASE/shared/$file" -o "$dest_file" 2>/dev/null; then
            print_warning "Could not download shared/$file, skipping..."
        fi
    done
}

# Function to validate project type
validate_project_type() {
    case "$PROJECT_TYPE" in
        console|library)
            return 0
            ;;
        *)
            print_error "Invalid project type: $PROJECT_TYPE"
            print_info "Valid types: console, library"
            exit 1
            ;;
    esac
}

# Function to validate project name
validate_project_name() {
    if [[ -z "$PROJECT_NAME" ]]; then
        print_error "Project name cannot be empty"
        exit 1
    fi
    
    # Check for valid C++ identifier (basic check)
    if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        print_warning "Project name should be a valid C++ identifier"
        print_info "Using name as-is, but consider using alphanumeric characters and underscores only"
    fi
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
                    -t|--templates)
            LOCAL_TEMPLATES_DIR="$2"
            shift 2
            ;;
            --author)
                AUTHOR="$2"
                shift 2
                ;;
            --version)
                VERSION="$2"
                shift 2
                ;;
            --description)
                DESCRIPTION="$2"
                shift 2
                ;;
            --no-shared)
                NO_SHARED=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$PROJECT_TYPE" ]]; then
                    PROJECT_TYPE="$1"
                elif [[ -z "$PROJECT_NAME" ]]; then
                    PROJECT_NAME="$1"
                else
                    print_error "Too many arguments: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Check required arguments
    if [[ -z "$PROJECT_TYPE" || -z "$PROJECT_NAME" ]]; then
        print_error "PROJECT_TYPE and PROJECT_NAME are required"
        show_usage
        exit 1
    fi
}

# Function to build Python command arguments
build_python_command() {
    cmd_args=("$PROJECT_TYPE" "$PROJECT_NAME")
    
    cmd_args+=(--output "$OUTPUT_DIR")
    cmd_args+=(--templates-dir "$TEMPLATES_DIR")
    
    if [[ -n "$CONFIG_FILE" ]]; then
        cmd_args+=(--config "$CONFIG_FILE")
    fi
    
    if [[ -n "$AUTHOR" ]]; then
        cmd_args+=(--author "$AUTHOR")
    fi
    
    if [[ -n "$VERSION" ]]; then
        cmd_args+=(--version "$VERSION")
    fi
    
    if [[ -n "$DESCRIPTION" ]]; then
        cmd_args+=(--description "$DESCRIPTION")
    fi
    
    if [[ "$NO_SHARED" == true ]]; then
        cmd_args+=(--no-shared)
    fi
}

# Function to create output directory if it doesn't exist
prepare_output_directory() {
    if [[ ! -d "$OUTPUT_DIR" ]]; then
        print_info "Creating output directory: $OUTPUT_DIR"
        mkdir -p "$OUTPUT_DIR"
    fi
    
    # Convert to absolute path for better display
    OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
}

# Main function
main() {
    print_info "C++20 Project Template Processor"
    print_info "================================"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check dependencies
    check_dependencies
    
    # Validate inputs
    validate_project_type
    validate_project_name
    
    # Prepare output directory
    prepare_output_directory
    
    # Build command arguments
    build_python_command
    
    if [[ "$VERBOSE" == true ]]; then
        print_info "Template processor: $TEMPLATE_PROCESSOR"
        print_info "Templates directory: $TEMPLATES_DIR"
        print_info "Output directory: $OUTPUT_DIR"
        print_info "Project type: $PROJECT_TYPE"
        print_info "Project name: $PROJECT_NAME"
        print_info "Command: python3 $TEMPLATE_PROCESSOR ${cmd_args[*]}"
        echo
    fi
    
    # Execute template processor
    print_info "Processing templates..."
    if python3 "$TEMPLATE_PROCESSOR" "${cmd_args[@]}"; then
        print_success "Template processing completed successfully!"
        print_info "Project files generated in: $OUTPUT_DIR"
        
        # Show generated files if verbose
        if [[ "$VERBOSE" == true ]]; then
            echo
            print_info "Generated files:"
            find "$OUTPUT_DIR" -type f -newer "$TEMPLATE_PROCESSOR" 2>/dev/null | head -20 | sed 's/^/  /'
        fi
    else
        print_error "Template processing failed"
        exit 1
    fi
}

# Run main function with all arguments
main "$@" 