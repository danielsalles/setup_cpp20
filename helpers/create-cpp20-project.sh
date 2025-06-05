#!/bin/bash

# 🏗️ C++20 PROJECT GENERATOR (Modern Template-Based Version)
# Creates production-ready C++20 projects using Jinja2 templates
# Usage: ./helpers/create-cpp20-project-modern.sh project-name [console|library]

set -euo pipefail

# 🎨 Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# 📊 Configuration
PROJECT_NAME="${1:-}"
PROJECT_TYPE="${2:-console}"  # console, library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_ROOT="$(dirname "$SCRIPT_DIR")"

# Repository configuration for remote access
REPO_BASE="https://raw.githubusercontent.com/danielsalles/setup_cpp20/main"
TEMPLATES_BASE="$REPO_BASE/templates"

# Local file paths (will be used if available, or downloaded if not)
TEMPLATE_PROCESSOR="$SCRIPT_DIR/template_processor.py"
PROCESS_TEMPLATES="$SCRIPT_DIR/process_templates.sh"
TEMPLATES_DIR="$SETUP_ROOT/templates"

# Temporary directory for downloads
TEMP_DIR=$(mktemp -d)

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}" >&2; }
log_header() { echo -e "${PURPLE}🚀 $*${NC}"; }

# Show help function
show_help() {
    show_banner
    echo -e "${CYAN}📚 USAGE${NC}"
    echo "  $0 <project-name> [project-type] [options]"
    echo
    echo -e "${CYAN}📝 ARGUMENTS${NC}"
    echo "  project-name    Name of the C++20 project to create"
    echo "  project-type    Type of project: console (default) or library"
    echo
    echo -e "${CYAN}⚙️  OPTIONS${NC}"
    echo "  -h, --help     Show this help message"
    echo
    echo -e "${CYAN}💡 EXAMPLES${NC}"
    echo "  $0 my-app                    # Create console application"
    echo "  $0 my-lib library            # Create library project"
    echo "  $0 hello-world console       # Create console app explicitly"
    echo
    echo -e "${CYAN}📋 FEATURES${NC}"
    echo "  ✅ Modern C++20 with concepts and ranges"
    echo "  ✅ CMake 3.25+ with modern practices"
    echo "  ✅ vcpkg integration for package management"
    echo "  ✅ Catch2 testing framework"
    echo "  ✅ Comprehensive development scripts"
    echo "  ✅ Cross-platform compatibility"
    echo "  ✅ Template-based code generation with Jinja2"
    echo
    echo -e "${CYAN}📦 REQUIREMENTS${NC}"
    echo "  • Python 3.6+ with Jinja2: pip install jinja2"
    echo "  • CMake 3.25+ and Ninja build system"
    echo "  • Modern C++20 compiler (GCC 11+, Clang 13+, MSVC 2022+)"
    echo
    echo -e "${CYAN}🔗 MORE INFO${NC}"
    echo "  Repository: https://github.com/danielsalles/setup_cpp20"
    echo "  Templates:  Uses Jinja2 for modern template processing"
    echo
}

# Cleanup function
cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║            🏗️ C++20 PROJECT GENERATOR                      ║
║                      (Template-Based)                      ║
║                                                            ║
║  Creates modern C++20 projects with:                       ║
║  • Jinja2 template system                                  ║
║  • CMake configuration                                     ║
║  • vcpkg integration                                       ║
║  • Testing framework                                       ║
║  • Modern C++20 examples                                   ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_template_system() {
    log_info "Checking template system availability..."
    
    # Check if Python 3 is available
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check if Jinja2 is available
    if ! python3 -c "import jinja2" 2>/dev/null; then
        log_error "Jinja2 is required but not installed"
        log_info "Install it with: pip install jinja2"
        exit 1
    fi
    
    # Check if we have local files or need to download them
    if [[ -f "$TEMPLATE_PROCESSOR" && -d "$TEMPLATES_DIR" ]]; then
        log_info "Using local template system"
        USE_LOCAL=true
    else
        log_info "Local template system not found, will download from repository"
        USE_LOCAL=false
        download_template_system
    fi
    
    log_success "Template system is available and ready"
}

download_template_system() {
    log_info "Downloading template processing system..."
    
    # Download template processor first
    log_info "Downloading template_processor.py..."
    if ! curl -fsSL "$REPO_BASE/helpers/template_processor.py" -o "$TEMP_DIR/template_processor.py"; then
        log_error "Failed to download template processor"
        exit 1
    fi
    
    # Update the template processor path to use temp directory
    TEMPLATE_PROCESSOR="$TEMP_DIR/template_processor.py"
    
    # Try to download entire repository as ZIP (more robust)
    log_info "Downloading complete template system from repository..."
    
    local repo_zip="$TEMP_DIR/setup_cpp20.zip"
    local extract_dir="$TEMP_DIR/extract"
    
    # Download repository ZIP
    if curl -fsSL "https://github.com/danielsalles/setup_cpp20/archive/main.zip" -o "$repo_zip" 2>/dev/null; then
        log_info "Repository archive downloaded successfully"
        
        # Extract ZIP file
        log_info "Extracting templates..."
        mkdir -p "$extract_dir"
        
        if command -v unzip >/dev/null 2>&1; then
            if unzip -q "$repo_zip" -d "$extract_dir" 2>/dev/null; then
                # Check if templates directory exists in extracted content
                if [[ -d "$extract_dir/setup_cpp20-main/templates" ]]; then
                    TEMPLATES_DIR="$extract_dir/setup_cpp20-main/templates"
                    log_success "Template system downloaded and extracted successfully"
                    
                    # Cleanup ZIP file
                    rm -f "$repo_zip"
                    return 0
                else
                    log_warning "Templates directory not found in archive"
                fi
            else
                log_warning "Failed to extract repository archive"
            fi
        else
            log_warning "unzip command not available"
        fi
        
        # Cleanup failed ZIP
        rm -f "$repo_zip"
    else
        log_warning "Failed to download repository archive"
    fi
    
    # Fallback: download templates individually
    log_info "Falling back to individual file downloads..."
    download_templates_individually
}

# Fallback function for individual file downloads
download_templates_individually() {
    log_info "Downloading templates individually..."
    
    # Create templates directory in temp
    mkdir -p "$TEMP_DIR/templates"
    TEMPLATES_DIR="$TEMP_DIR/templates"
    
    # Download console templates
    download_template_files "console"
    
    # Download library templates
    download_template_files "library"
    
    # Download shared templates
    download_shared_templates
    
    log_success "Template system downloaded individually"
}

download_template_files() {
    local project_type="$1"
    local template_dir="$TEMPLATES_DIR/$project_type"
    
    log_info "Downloading $project_type templates..."
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
        
        log_info "  Downloading $file..."
        if ! curl -fsSL "$base_url/$file" -o "$dest_file" 2>/dev/null; then
            log_warning "  Could not download $file, skipping..."
        fi
    done
}

download_shared_templates() {
    log_info "Downloading shared templates..."
    
    local shared_dir="$TEMPLATES_DIR/shared"
    mkdir -p "$shared_dir"
    
    # Download critical shared files
    local shared_files=(
        "cmake/CompilerWarnings.cmake"
        "cmake/VcpkgHelpers.cmake"
        "scripts/build.sh.template"
        "scripts/test.sh.template"
        ".clang-format.template"
        "Doxyfile.template"
    )
    
    for file in "${shared_files[@]}"; do
        local dest_file="$shared_dir/$file"
        mkdir -p "$(dirname "$dest_file")"
        
        log_info "  Downloading shared/$file..."
        if ! curl -fsSL "$TEMPLATES_BASE/shared/$file" -o "$dest_file" 2>/dev/null; then
            log_warning "  Could not download shared/$file, skipping..."
        fi
    done
}

get_project_info() {
    if [[ -z "$PROJECT_NAME" ]]; then
        echo -e "${CYAN}Enter project details:${NC}"
        read -p "Project name: " PROJECT_NAME
        
        echo "Project types:"
        echo "  1) console - Console application (default)"
        echo "  2) library - Static/shared library"
        read -p "Project type (1-2): " choice
        
        case $choice in
            2) PROJECT_TYPE="library" ;;
            *) PROJECT_TYPE="console" ;;
        esac
    fi
    
    if [[ -z "$PROJECT_NAME" ]] || [[ "$PROJECT_NAME" =~ [^a-zA-Z0-9_-] ]]; then
        log_error "Invalid project name. Use only letters, numbers, underscores, and hyphens."
        exit 1
    fi
    
    if [[ -d "$PROJECT_NAME" ]]; then
        log_error "Directory '$PROJECT_NAME' already exists"
        exit 1
    fi
}

create_project_structure() {
    log_header "Creating Project Structure"
    
    # Create base project directory
    mkdir -p "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    
    # Create project-specific directory structures
    case "$PROJECT_TYPE" in
        "console")
            create_console_structure
            ;;
        "library")
            create_library_structure
            ;;
        *)
            log_error "Unknown project type: $PROJECT_TYPE"
            exit 1
            ;;
    esac
    
    # Create common directories for all project types
    create_common_structure
    
    log_success "Directory structure created for $PROJECT_TYPE project"
}

create_console_structure() {
    log_info "Creating console application structure..."
    
    # Console applications have a simple flat structure
    mkdir -p src
    
    # Create a basic directory for future expansion
    mkdir -p include/"$PROJECT_NAME"
    
    log_info "Console structure: src/, include/$PROJECT_NAME/"
}

create_library_structure() {
    log_info "Creating library structure..."
    
    # Library projects need more organized structure
    mkdir -p include/"$PROJECT_NAME"
    mkdir -p src
    mkdir -p examples
    mkdir -p docs
    
    # For libraries, create additional directories
    mkdir -p include/"$PROJECT_NAME"/detail  # Internal implementation details
    
    log_info "Library structure: include/$PROJECT_NAME/, src/, examples/, docs/"
}

create_common_structure() {
    log_info "Creating common project structure..."
    
    # Common directories for all project types
    mkdir -p tests
    mkdir -p scripts
    mkdir -p cmake
    mkdir -p third_party  # For external dependencies
    mkdir -p build        # Build directory (will be ignored by git)
    
    # Create .vscode directory for VS Code configuration
    mkdir -p .vscode
    
    log_info "Common structure: tests/, scripts/, cmake/, third_party/, .vscode/"
}

initialize_vcpkg_manifest() {
    log_info "Initializing vcpkg.json manifest..."
    if [[ -f "vcpkg.json" ]]; then
        log_info "vcpkg.json already exists."
        return 0
    fi

    # Get project name from the current directory if PROJECT_NAME variable isn't set
    # (should be set, but as a fallback)
    local manifest_project_name="${PROJECT_NAME:-$(basename "$(pwd)")}"
    
    # Convert to lowercase using tr (more compatible than ${var,,})
    local lowercase_name=$(echo "$manifest_project_name" | tr '[:upper:]' '[:lower:]')

    cat > vcpkg.json << EOF
{
  "name": "$lowercase_name",
  "version-string": "1.0.0",
  "description": "Dependencies for $manifest_project_name",
  "dependencies": [
  ]
}
EOF

    log_success "vcpkg.json created successfully."
}

create_project_config() {
    log_header "Generating Project Configuration"
    
    # Create a configuration file for the template processor
    local config_file="project_config.json"
    
    # Get current user for author field
    local author="${USER:-Developer}"
    
    # Get project-specific configuration
    local project_config
    project_config=$(get_project_specific_config)
    
    cat > "$config_file" << CONFIG_EOF
{
  "project_name": "$PROJECT_NAME",
  "project_version": "1.0.0",
  "project_description": "Modern C++20 $PROJECT_TYPE project",
  "project_author": "$author",
  "project_type": "$PROJECT_TYPE",
  "cpp_standard": "20",
  "cmake_version": "3.25",
  "enable_testing": true,
  "enable_sanitizers": true,
  "enable_warnings": true,
  "use_vcpkg": true,
  $project_config
  "compiler_options": {
    "enable_lto": false,
    "enable_static_analysis": true,
    "warning_level": "strict"
  },
  "build_configuration": {
    "default_build_type": "Release",
    "enable_debug_info": true,
    "enable_profiling": false
  },
  "project_metadata": {
    "license": "MIT",
    "homepage": "https://github.com/your-username/$PROJECT_NAME",
    "repository": "https://github.com/your-username/$PROJECT_NAME.git",
    "bug_tracker": "https://github.com/your-username/$PROJECT_NAME/issues"
  }
}
CONFIG_EOF
    
    log_success "Project configuration created for $PROJECT_TYPE"
}

get_project_specific_config() {
    case "$PROJECT_TYPE" in
        "console")
            cat << 'CONSOLE_CONFIG'
  "optional_libraries": {
    "fmt": true,
    "spdlog": true,
    "catch2": true,
    "boost": false,
    "openssl": false
  },
  "console_specific": {
    "create_main_source": true,
    "enable_command_line_parsing": false,
    "enable_logging": true
  },
CONSOLE_CONFIG
            ;;
        "library")
            cat << 'LIBRARY_CONFIG'
  "optional_libraries": {
    "fmt": false,
    "spdlog": false,
    "catch2": true,
    "boost": false,
    "openssl": false
  },
  "library_specific": {
    "build_shared": true,
    "build_static": true,
    "create_examples": true,
    "export_cmake_config": true,
    "generate_pkg_config": true
  },
LIBRARY_CONFIG
            ;;
        *)
            cat << 'DEFAULT_CONFIG'
  "optional_libraries": {
    "fmt": false,
    "spdlog": false,
    "catch2": true,
    "boost": false,
    "openssl": false
  },
DEFAULT_CONFIG
            ;;
    esac
}

generate_project_from_templates() {
    log_header "Generating Project from Templates"
    
    # Use our template processing system
    log_info "Processing templates with Jinja2..."
    
    # Choose the appropriate method based on what's available
    if [[ "$USE_LOCAL" == true && -f "$PROCESS_TEMPLATES" ]]; then
        # Use local wrapper script
        log_info "Using local process_templates.sh wrapper..."
        if "$PROCESS_TEMPLATES" "$PROJECT_TYPE" "$PROJECT_NAME" \
            --output "." \
            --config "project_config.json" \
            --verbose; then
            log_success "Project generated from templates successfully"
        else
            log_error "Failed to generate project from templates"
            exit 1
        fi
    else
        # Use Python template processor directly
        log_info "Using Python template processor directly..."
        if python3 "$TEMPLATE_PROCESSOR" "$PROJECT_TYPE" "$PROJECT_NAME" \
            --output "." \
            --config "project_config.json" \
            --templates-dir "$TEMPLATES_DIR"; then
            log_success "Project generated from templates successfully"
        else
            log_error "Failed to generate project from templates"
            exit 1
        fi
    fi
    
    # Clean up temporary config file
    rm -f "project_config.json"
    
    # Create additional project files
    create_additional_project_files
}

create_additional_project_files() {
    log_info "Creating additional project files..."
    
    # Create VS Code configuration
    create_vscode_config
    
    # Create development scripts
    create_development_scripts
    
    # Create documentation files
    create_documentation_files
    
    log_success "Additional project files created"
}

create_vscode_config() {
    log_info "Creating VS Code configuration..."
    
    # Create settings.json for VS Code
    cat > .vscode/settings.json << 'VSCODE_SETTINGS'
{
    "cmake.configureOnOpen": true,
    "cmake.buildDirectory": "${workspaceFolder}/build",
    "cmake.generator": "Ninja",
    "cmake.buildArgs": ["-j", "8"],
    "cmake.parallelJobs": 8,
    "cpp.default.cppStandard": "c++20",
    "cpp.default.compilerPath": "/usr/bin/clang++",
    "cpp.default.configurationProvider": "ms-vscode.cmake-tools",
    "files.associations": {
        "*.hpp": "cpp",
        "*.h": "cpp",
        "*.cpp": "cpp",
        "*.cc": "cpp",
        "*.cxx": "cpp"
    },
    "editor.rulers": [80, 120],
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "editor.trimAutoWhitespace": true,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true
}
VSCODE_SETTINGS

    # Create launch.json for debugging
    cat > .vscode/launch.json << VSCODE_LAUNCH
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug ${PROJECT_NAME}",
            "type": "cppdbg",
            "request": "launch",
            "program": "\${workspaceFolder}/build/${PROJECT_NAME}",
            "args": [],
            "stopAtEntry": false,
            "cwd": "\${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "lldb",
            "preLaunchTask": "build"
        }
    ]
}
VSCODE_LAUNCH

    # Create tasks.json for build tasks
    cat > .vscode/tasks.json << 'VSCODE_TASKS'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "configure",
            "type": "shell",
            "command": "cmake",
            "args": ["-B", "build", "-G", "Ninja"],
            "group": "build",
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "build",
            "type": "shell",
            "command": "cmake",
            "args": ["--build", "build"],
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "dependsOn": "configure",
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "clean",
            "type": "shell",
            "command": "cmake",
            "args": ["--build", "build", "--target", "clean"],
            "group": "build",
            "options": {
                "cwd": "${workspaceFolder}"
            }
        },
        {
            "label": "test",
            "type": "shell",
            "command": "ctest",
            "args": ["--test-dir", "build", "--output-on-failure"],
            "group": "test",
            "dependsOn": "build",
            "options": {
                "cwd": "${workspaceFolder}"
            }
        }
    ]
}
VSCODE_TASKS

    log_info "VS Code configuration created (.vscode/)"
}

create_development_scripts() {
    log_info "Creating development scripts..."
    
    # Create quick build script
    cat > scripts/quick-build.sh << 'QUICK_BUILD'
#!/bin/bash
# Quick build script for development

set -euo pipefail

cd "$(dirname "$0")/.."

echo "🔨 Quick build..."
cmake -B build -G Ninja
cmake --build build

echo "✅ Build complete"
QUICK_BUILD

    # Create test script
    cat > scripts/run-tests.sh << 'RUN_TESTS'
#!/bin/bash
# Run all tests

set -euo pipefail

cd "$(dirname "$0")/.."

echo "🧪 Running tests..."
cmake -B build -G Ninja
cmake --build build
ctest --test-dir build --output-on-failure

echo "✅ Tests complete"
RUN_TESTS

    # Create format script
    cat > scripts/format-code.sh << 'FORMAT_CODE'
#!/bin/bash
# Format code using clang-format

set -euo pipefail

cd "$(dirname "$0")/.."

echo "🎨 Formatting code..."

# Find all C++ files and format them
find src include tests -name "*.cpp" -o -name "*.hpp" -o -name "*.h" | \
    xargs clang-format -i -style=file

echo "✅ Code formatted"
FORMAT_CODE

    # Make scripts executable
    chmod +x scripts/*.sh
    
    log_info "Development scripts created (scripts/)"
}

create_documentation_files() {
    log_info "Creating documentation files..."
    
    # Create clang-format configuration
    cat > .clang-format << 'CLANG_FORMAT'
BasedOnStyle: Google
IndentWidth: 4
AccessModifierOffset: -2
AlignAfterOpenBracket: Align
AlignConsecutiveAssignments: false
AlignConsecutiveDeclarations: false
AlignEscapedNewlines: Left
AlignOperands: true
AlignTrailingComments: true
AllowAllArgumentsOnNextLine: true
AllowAllConstructorInitializersOnNextLine: true
AllowAllParametersOfDeclarationOnNextLine: true
AllowShortBlocksOnASingleLine: Never
AllowShortCaseLabelsOnASingleLine: false
AllowShortFunctionsOnASingleLine: Empty
AllowShortIfStatementsOnASingleLine: Never
AllowShortLambdasOnASingleLine: All
AllowShortLoopsOnASingleLine: false
BinPackArguments: true
BinPackParameters: true
BreakBeforeBraces: Attach
BreakBeforeTernaryOperators: true
BreakConstructorInitializers: BeforeColon
BreakInheritanceList: BeforeColon
ColumnLimit: 100
CompactNamespaces: false
ConstructorInitializerAllOnOneLineOrOnePerLine: true
ConstructorInitializerIndentWidth: 4
ContinuationIndentWidth: 4
Cpp11BracedListStyle: true
DeriveLineEnding: true
DerivePointerAlignment: false
FixNamespaceComments: true
IncludeBlocks: Preserve
IndentCaseLabels: true
IndentPPDirectives: None
IndentWrappedFunctionNames: false
KeepEmptyLinesAtTheStartOfBlocks: false
Language: Cpp
MaxEmptyLinesToKeep: 1
NamespaceIndentation: None
PointerAlignment: Left
ReflowComments: true
SortIncludes: true
SortUsingDeclarations: true
SpaceAfterCStyleCast: false
SpaceAfterLogicalNot: false
SpaceAfterTemplateKeyword: true
SpaceBeforeAssignmentOperators: true
SpaceBeforeCpp11BracedList: false
SpaceBeforeCtorInitializerColon: true
SpaceBeforeInheritanceColon: true
SpaceBeforeParens: ControlStatements
SpaceBeforeRangeBasedForLoopColon: true
SpaceInEmptyParentheses: false
SpacesBeforeTrailingComments: 2
SpacesInAngles: false
SpacesInCStyleCastParentheses: false
SpacesInContainerLiterals: true
SpacesInParentheses: false
SpacesInSquareBrackets: false
Standard: Latest
TabWidth: 4
UseTab: Never
CLANG_FORMAT

    # Create .gitattributes for line ending consistency
    cat > .gitattributes << 'GITATTRIBUTES'
# Auto detect text files and perform LF normalization
* text=auto

# Source files
*.cpp text
*.hpp text
*.h text
*.c text
*.cc text
*.cxx text

# CMake files
*.cmake text
CMakeLists.txt text

# Configuration files
*.json text
*.yaml text
*.yml text
*.toml text
*.ini text

# Documentation
*.md text
*.txt text

# Shell scripts
*.sh text eol=lf

# Batch files
*.bat text eol=crlf
*.cmd text eol=crlf

# Binary files
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.zip binary
*.tar binary
*.gz binary
*.7z binary
*.exe binary
*.dll binary
*.so binary
*.dylib binary
*.a binary
*.lib binary
*.o binary
*.obj binary
GITATTRIBUTES

    log_info "Configuration files created (.clang-format, .gitattributes)"
}

test_generated_project() {
    log_header "Testing Generated Project"
    
    if [[ ! -f "CMakeLists.txt" ]]; then
        log_warning "CMakeLists.txt not found, skipping build test"
        return
    fi
    
    log_info "Testing project build..."
    
    # Create build directory and test compilation
    if mkdir -p build && cd build; then
        if cmake .. -G Ninja &>/dev/null && ninja &>/dev/null; then
            log_success "Project builds successfully"
            
            # Test executable
            if [[ -f "$PROJECT_NAME" ]]; then
                log_info "Testing executable..."
                if ./"$PROJECT_NAME" &>/dev/null; then
                    log_success "Executable runs successfully"
                fi
            fi
        else
            log_warning "Build test failed (may need dependencies)"
        fi
        cd ..
    fi
}

show_completion() {
    log_header "Project Created Successfully!"
    
    echo -e "${GREEN}"
    cat << COMPLETION_EOF
🎉 Modern C++20 project '${PROJECT_NAME}' created!

📁 Project: ${PROJECT_NAME}/ (${PROJECT_TYPE})

🚀 Next steps:
  cd ${PROJECT_NAME}
  
  # Install dependencies (if using vcpkg):
  vcpkg install
  
  # Build project:
  mkdir build && cd build
  cmake .. -G Ninja
  ninja
  
  # Run tests:
  ctest

📦 Adding dependencies:
  Edit vcpkg.json to add packages, then run 'vcpkg install'

🔧 Development:
  Use scripts in scripts/ directory for common tasks

📚 Features:
  ✅ C++20 with concepts and ranges
  ✅ vcpkg with automatic package discovery
  ✅ Catch2 testing framework
  ✅ Modern CMake configuration
  ✅ Template-based generation

Generated using the modern Jinja2 template system! 🎯
COMPLETION_EOF
    echo -e "${NC}"
}

main() {
    # Check for help argument first
    for arg in "$@"; do
        case $arg in
            -h|--help)
                show_help
                exit 0
                ;;
        esac
    done
    
    show_banner
    check_template_system
    get_project_info
    
    log_info "Creating C++20 project: $PROJECT_NAME"
    log_info "Type: $PROJECT_TYPE | Templates: Jinja2 | Testing: enabled"
    echo
    
    create_project_structure
    initialize_vcpkg_manifest
    create_project_config
    generate_project_from_templates
    test_generated_project
    
    show_completion
}

main "$@" 