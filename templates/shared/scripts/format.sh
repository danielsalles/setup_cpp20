#!/bin/bash

# {{ project_name }} Code Formatting Script
# Automatic code formatting using clang-format with advanced features

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

# Detect clang-format binary
detect_clang_format() {
    local clang_format_paths=(
        "clang-format"
        "clang-format-18"
        "clang-format-17"
        "clang-format-16"
        "clang-format-15"
        "/usr/local/bin/clang-format"
        "/opt/homebrew/bin/clang-format"
    )
    
    for cf_path in "${clang_format_paths[@]}"; do
        if command -v "$cf_path" >/dev/null 2>&1; then
            echo "$cf_path"
            return 0
        fi
    done
    
    return 1
}

# Get clang-format version
get_clang_format_version() {
    local cf_binary="$1"
    "$cf_binary" --version | grep -o '[0-9]\+\.[0-9]\+' | head -n1
}

# Find configuration file
find_config_file() {
    local search_dir="${1:-$PROJECT_ROOT}"
    local config_names=(".clang-format" "_clang-format")
    
    # Search current directory and parent directories
    local current_dir="$search_dir"
    while [[ "$current_dir" != "/" ]]; do
        for config_name in "${config_names[@]}"; do
            local config_path="$current_dir/$config_name"
            if [[ -f "$config_path" ]]; then
                echo "$config_path"
                return 0
            fi
        done
        current_dir="$(dirname "$current_dir")"
    done
    
    return 1
}

# Create default .clang-format if none exists
create_default_config() {
    local config_file="$PROJECT_ROOT/.clang-format"
    
    log_info "Creating default .clang-format configuration..."
    
    cat > "$config_file" << 'EOF'
---
# {{ project_name }} clang-format configuration
# Based on Google style with C++20 modifications

BasedOnStyle: Google
Language: Cpp
Standard: c++20

# Indentation
IndentWidth: 4
TabWidth: 4
UseTab: Never
IndentCaseLabels: true
IndentPPDirectives: BeforeHash
IndentWrappedFunctionNames: false

# Line Length
ColumnLimit: 120
ReflowComments: true

# Braces
BreakBeforeBraces: Attach
Cpp11BracedListStyle: true
SpaceBeforeCpp11BracedList: false

# Spaces
SpaceAfterCStyleCast: false
SpaceAfterLogicalNot: false
SpaceAfterTemplateKeyword: true
SpaceBeforeAssignmentOperators: true
SpaceBeforeParens: ControlStatements
SpaceInEmptyParentheses: false
SpacesInAngles: false
SpacesInCStyleCastParentheses: false
SpacesInParentheses: false
SpacesInSquareBrackets: false

# Alignment
AlignAfterOpenBracket: Align
AlignConsecutiveAssignments: false
AlignConsecutiveDeclarations: false
AlignEscapedNewlines: Left
AlignOperands: true
AlignTrailingComments: true

# Breaking
AllowAllParametersOfDeclarationOnNextLine: true
AllowShortBlocksOnASingleLine: false
AllowShortCaseLabelsOnASingleLine: false
AllowShortFunctionsOnASingleLine: All
AllowShortIfStatementsOnASingleLine: true
AllowShortLoopsOnASingleLine: true
AlwaysBreakAfterDefinitionReturnType: None
AlwaysBreakAfterReturnType: None
AlwaysBreakBeforeMultilineStrings: true
AlwaysBreakTemplateDeclarations: Yes
BinPackArguments: true
BinPackParameters: true
BreakBeforeBinaryOperators: None
BreakBeforeTernaryOperators: true
BreakConstructorInitializers: BeforeColon
BreakStringLiterals: true

# Sorting
SortIncludes: true
SortUsingDeclarations: true
IncludeBlocks: Preserve

# Other
CompactNamespaces: false
ConstructorInitializerAllOnOneLineOrOnePerLine: true
ConstructorInitializerIndentWidth: 4
ContinuationIndentWidth: 4
DerivePointerAlignment: false
DisableFormat: false
ExperimentalAutoDetectBinPacking: false
FixNamespaceComments: true
ForEachMacros: ['RANGES_FOR', 'FOREACH']
KeepEmptyLinesAtTheStartOfBlocks: false
MacroBlockBegin: ''
MacroBlockEnd: ''
MaxEmptyLinesToKeep: 1
NamespaceIndentation: None
PenaltyBreakAssignment: 2
PenaltyBreakBeforeFirstCallParameter: 1
PenaltyBreakComment: 300
PenaltyBreakFirstLessLess: 120
PenaltyBreakString: 1000
PenaltyBreakTemplateDeclaration: 10
PenaltyExcessCharacter: 1000000
PenaltyReturnTypeOnItsOwnLine: 200
PointerAlignment: Left
SpaceAfterCStyleCast: false
SpaceBeforeCtorInitializerColon: true
SpaceBeforeInheritanceColon: true
SpaceBeforeRangeBasedForLoopColon: true
...
EOF
    
    log_success "Created default .clang-format configuration: $config_file"
}

# Find source files
find_source_files() {
    local search_paths=("${@:-$PROJECT_ROOT}")
    local file_extensions=("*.cpp" "*.cxx" "*.cc" "*.c" "*.hpp" "*.hxx" "*.hh" "*.h")
    local exclude_patterns=("build/" "cmake-build-*/" ".git/" "third_party/" "external/" "vendor/")
    
    local find_args=()
    
    # Add search paths
    for path in "${search_paths[@]}"; do
        if [[ -e "$path" ]]; then
            find_args+=("$path")
        fi
    done
    
    # Add exclude patterns
    for pattern in "${exclude_patterns[@]}"; do
        find_args+=("-path" "*/$pattern" "-prune" "-o")
    done
    
    # Add file extensions
    find_args+=("(")
    for i in "${!file_extensions[@]}"; do
        find_args+=("-name" "${file_extensions[$i]}")
        if [[ $i -lt $((${#file_extensions[@]} - 1)) ]]; then
            find_args+=("-o")
        fi
    done
    find_args+=(")" "-print")
    
    log_debug "Find command: find ${find_args[*]}"
    find "${find_args[@]}" 2>/dev/null | sort
}

# Get changed files from git
get_git_changed_files() {
    local git_base="${1:-HEAD}"
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        return 1
    fi
    
    local changed_files=()
    
    # Get staged files
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]] && is_source_file "$file"; then
            changed_files+=("$file")
        fi
    done < <(git diff --cached --name-files --diff-filter=ACMR -z 2>/dev/null || true)
    
    # Get unstaged files
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]] && is_source_file "$file"; then
            changed_files+=("$file")
        fi
    done < <(git diff --name-files --diff-filter=ACMR -z 2>/dev/null || true)
    
    # Get untracked files
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]] && is_source_file "$file"; then
            changed_files+=("$file")
        fi
    done < <(git ls-files --others --exclude-standard -z 2>/dev/null || true)
    
    # Remove duplicates and sort
    printf '%s\n' "${changed_files[@]}" | sort -u
}

# Check if file is a source file
is_source_file() {
    local file="$1"
    local source_extensions=("cpp" "cxx" "cc" "c" "hpp" "hxx" "hh" "h")
    
    for ext in "${source_extensions[@]}"; do
        if [[ "$file" == *."$ext" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Format single file
format_file() {
    local file="$1"
    local check_only="${2:-false}"
    local cf_binary="$3"
    local config_file="${4:-}"
    
    if [[ ! -f "$file" ]]; then
        log_warning "File not found: $file"
        return 1
    fi
    
    local cf_args=("$cf_binary")
    
    # Add config file if specified
    if [[ -n "$config_file" ]] && [[ -f "$config_file" ]]; then
        cf_args+=("-style=file:$config_file")
    else
        cf_args+=("-style=file")
    fi
    
    if [[ "$check_only" == true ]]; then
        # Check if file would be changed
        local original_content
        original_content="$(cat "$file")"
        local formatted_content
        formatted_content="$("${cf_args[@]}" "$file" 2>/dev/null)"
        
        if [[ "$original_content" != "$formatted_content" ]]; then
            log_warning "File needs formatting: $file"
            if [[ "${VERBOSE:-false}" == true ]]; then
                log_debug "Diff for $file:"
                diff -u "$file" <(echo "$formatted_content") || true
            fi
            return 1
        else
            log_debug "File already formatted: $file"
            return 0
        fi
    else
        # Format file in place
        if "${cf_args[@]}" -i "$file" 2>/dev/null; then
            log_debug "Formatted: $file"
            return 0
        else
            log_error "Failed to format: $file"
            return 1
        fi
    fi
}

# Setup pre-commit hook
setup_pre_commit_hook() {
    local hooks_dir="$PROJECT_ROOT/.git/hooks"
    local pre_commit_file="$hooks_dir/pre-commit"
    
    if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
        log_error "Not in a git repository"
        return 1
    fi
    
    mkdir -p "$hooks_dir"
    
    # Create or update pre-commit hook
    cat > "$pre_commit_file" << 'EOF'
#!/bin/bash

# Pre-commit hook for automatic code formatting
# Generated by {{ project_name }} format.sh script

set -e

# Find the format script relative to git root
REPO_ROOT="$(git rev-parse --show-toplevel)"
FORMAT_SCRIPT="$REPO_ROOT/scripts/format.sh"

# Fallback to shared scripts location
if [[ ! -f "$FORMAT_SCRIPT" ]]; then
    FORMAT_SCRIPT="$REPO_ROOT/templates/shared/scripts/format.sh"
fi

if [[ ! -f "$FORMAT_SCRIPT" ]]; then
    echo "Warning: format.sh script not found, skipping formatting check"
    exit 0
fi

# Check formatting of staged files
echo "Checking code formatting..."
if ! "$FORMAT_SCRIPT" --check --git-changed --quiet; then
    echo "Code formatting check failed!"
    echo "Please run: $FORMAT_SCRIPT --git-changed"
    echo "Then stage the changes and commit again."
    exit 1
fi

echo "Code formatting check passed!"
EOF
    
    chmod +x "$pre_commit_file"
    log_success "Pre-commit hook installed: $pre_commit_file"
}

# Print usage information
print_usage() {
    cat << EOF
${BOLD}{{ project_name }} Code Formatting Script${NC}
Automatic code formatting using clang-format with advanced features

${BOLD}USAGE:${NC}
    $0 [OPTIONS] [FILES/DIRECTORIES...]

${BOLD}FORMATTING OPTIONS:${NC}
    -c, --check             Check if files need formatting (don't modify files)
    -i, --in-place          Format files in place (default)
    --config FILE           Use specific clang-format config file
    --create-config         Create default .clang-format configuration
    --style STYLE           Use predefined style (Google, LLVM, Chromium, Mozilla, WebKit)

${BOLD}FILE SELECTION:${NC}
    --git-changed           Only format git changed/staged/untracked files
    --git-diff BASE         Format files changed since BASE commit (default: HEAD)
    --extensions EXTS       File extensions to process (default: cpp,cxx,cc,c,hpp,hxx,hh,h)
    --exclude PATTERNS      Exclude paths matching patterns (comma-separated)

${BOLD}OUTPUT OPTIONS:${NC}
    -v, --verbose           Enable verbose output with detailed information
    -q, --quiet             Suppress non-essential output
    --color                 Force colored output
    --no-color              Disable colored output

${BOLD}INTEGRATION OPTIONS:${NC}
    --install-hook          Install git pre-commit hook for automatic checking
    --uninstall-hook        Remove git pre-commit hook
    --diff                  Show diff of changes (with --check)

${BOLD}UTILITY OPTIONS:${NC}
    --version               Show clang-format version and exit
    --list-styles           List available predefined styles
    -h, --help              Show this help message

${BOLD}EXAMPLES:${NC}
    $0                                  # Format all source files in project
    $0 --check                          # Check if any files need formatting
    $0 --git-changed                    # Format only changed files
    $0 --check --git-changed            # Check only changed files
    $0 src/ include/                    # Format specific directories
    $0 --config .my-format --verbose    # Use custom config with verbose output
    $0 --create-config                  # Create default .clang-format
    $0 --install-hook                   # Setup pre-commit formatting check

${BOLD}CONFIGURATION:${NC}
    The script searches for .clang-format files in the current directory and parent
    directories. If none found, use --create-config to generate a default configuration.

${BOLD}EXIT CODES:${NC}
    0    Success (all files formatted or already properly formatted)
    1    Error (formatting failed or files need formatting in check mode)
    2    Configuration error (missing clang-format, invalid config, etc.)

EOF
}

# Default values
CHECK_ONLY=false
CONFIG_FILE=""
CREATE_CONFIG=false
STYLE=""
GIT_CHANGED=false
GIT_BASE="HEAD"
EXTENSIONS="cpp,cxx,cc,c,hpp,hxx,hh,h"
EXCLUDE_PATTERNS=""
VERBOSE=false
QUIET=false
FORCE_COLOR=""
INSTALL_HOOK=false
UNINSTALL_HOOK=false
SHOW_DIFF=false
SHOW_VERSION=false
LIST_STYLES=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        -i|--in-place)
            CHECK_ONLY=false
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --create-config)
            CREATE_CONFIG=true
            shift
            ;;
        --style)
            STYLE="$2"
            shift 2
            ;;
        --git-changed)
            GIT_CHANGED=true
            shift
            ;;
        --git-diff)
            GIT_CHANGED=true
            GIT_BASE="$2"
            shift 2
            ;;
        --extensions)
            EXTENSIONS="$2"
            shift 2
            ;;
        --exclude)
            EXCLUDE_PATTERNS="$2"
            shift 2
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
        --install-hook)
            INSTALL_HOOK=true
            shift
            ;;
        --uninstall-hook)
            UNINSTALL_HOOK=true
            shift
            ;;
        --diff)
            SHOW_DIFF=true
            shift
            ;;
        --version)
            SHOW_VERSION=true
            shift
            ;;
        --list-styles)
            LIST_STYLES=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            print_usage
            exit 2
            ;;
        *)
            # Remaining arguments are files/directories
            break
            ;;
    esac
done

# Handle color output
if [[ "$FORCE_COLOR" == false ]] || [[ ! -t 1 ]] || [[ "$QUIET" == true ]]; then
    RED="" GREEN="" YELLOW="" BLUE="" PURPLE="" CYAN="" BOLD="" NC=""
fi

# Main execution
main() {
    # Detect clang-format
    local cf_binary
    if ! cf_binary="$(detect_clang_format)"; then
        log_error "clang-format not found. Please install clang-format."
        log_info "On macOS: brew install clang-format"
        log_info "On Ubuntu: apt-get install clang-format"
        exit 2
    fi
    
    log_debug "Using clang-format: $cf_binary"
    
    # Show version if requested
    if [[ "$SHOW_VERSION" == true ]]; then
        local version
        version="$(get_clang_format_version "$cf_binary")"
        echo "clang-format version: $version"
        echo "Binary location: $cf_binary"
        exit 0
    fi
    
    # List styles if requested
    if [[ "$LIST_STYLES" == true ]]; then
        echo "Available predefined styles:"
        echo "  LLVM, Google, Chromium, Mozilla, WebKit"
        echo "  GNU, Microsoft, InheritParentConfig"
        exit 0
    fi
    
    # Create config if requested
    if [[ "$CREATE_CONFIG" == true ]]; then
        create_default_config
        exit 0
    fi
    
    # Install/uninstall hooks
    if [[ "$INSTALL_HOOK" == true ]]; then
        setup_pre_commit_hook
        exit 0
    fi
    
    if [[ "$UNINSTALL_HOOK" == true ]]; then
        local pre_commit_file="$PROJECT_ROOT/.git/hooks/pre-commit"
        if [[ -f "$pre_commit_file" ]]; then
            rm "$pre_commit_file"
            log_success "Pre-commit hook removed"
        else
            log_warning "No pre-commit hook found"
        fi
        exit 0
    fi
    
    # Find configuration file
    local config_file="$CONFIG_FILE"
    if [[ -z "$config_file" ]] && [[ -z "$STYLE" ]]; then
        if config_file="$(find_config_file)"; then
            log_debug "Using config file: $config_file"
        else
            log_warning "No .clang-format file found. Use --create-config to generate one."
            log_info "Using default Google style"
            STYLE="Google"
        fi
    fi
    
    # Apply custom style if specified
    if [[ -n "$STYLE" ]]; then
        config_file=""  # Clear config file when using predefined style
        log_debug "Using predefined style: $STYLE"
    fi
    
    # Get files to format
    local files_to_format=()
    
    if [[ "$GIT_CHANGED" == true ]]; then
        log_info "Finding git changed files..."
        while IFS= read -r file; do
            files_to_format+=("$file")
        done < <(get_git_changed_files "$GIT_BASE")
    else
        # Use specified paths or default to project root
        local search_paths=("$@")
        if [[ ${#search_paths[@]} -eq 0 ]]; then
            search_paths=("$PROJECT_ROOT")
        fi
        
        log_info "Finding source files in: ${search_paths[*]}"
        while IFS= read -r file; do
            files_to_format+=("$file")
        done < <(find_source_files "${search_paths[@]}")
    fi
    
    if [[ ${#files_to_format[@]} -eq 0 ]]; then
        log_warning "No source files found to format"
        exit 0
    fi
    
    log_info "Found ${#files_to_format[@]} source files to process"
    
    # Format files
    local failed_files=()
    local formatted_count=0
    
    for file in "${files_to_format[@]}"; do
        if format_file "$file" "$CHECK_ONLY" "$cf_binary" "$config_file"; then
            ((formatted_count++)) || true
        else
            failed_files+=("$file")
        fi
    done
    
    # Summary
    if [[ "$QUIET" != true ]]; then
        echo
        if [[ "$CHECK_ONLY" == true ]]; then
            if [[ ${#failed_files[@]} -eq 0 ]]; then
                log_success "All ${#files_to_format[@]} files are properly formatted"
            else
                log_warning "${#failed_files[@]} files need formatting:"
                printf '  %s\n' "${failed_files[@]}"
            fi
        else
            if [[ ${#failed_files[@]} -eq 0 ]]; then
                log_success "Successfully formatted ${#files_to_format[@]} files"
            else
                log_error "Failed to format ${#failed_files[@]} files"
                printf '  %s\n' "${failed_files[@]}"
            fi
        fi
    fi
    
    # Exit with appropriate code
    if [[ ${#failed_files[@]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@" 