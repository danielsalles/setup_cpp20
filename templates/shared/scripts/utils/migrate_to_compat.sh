#!/usr/bin/env bash
# Script to help migrate existing scripts to use platform_compat.sh

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMPAT_LIB="${SCRIPT_DIR}/platform_compat.sh"

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <script_file>

Migrate a bash script to use the platform compatibility layer.

Options:
    -h, --help          Show this help message
    -d, --dry-run       Show what would be changed without modifying the file
    -b, --backup        Create a backup of the original file
    -i, --interactive   Ask before each change
    -v, --verbose       Show detailed output

Examples:
    $0 build.sh                    # Migrate build.sh
    $0 --dry-run test.sh          # Preview changes for test.sh
    $0 --backup --interactive *.sh # Migrate all .sh files with backup

EOF
}

# Parse arguments
DRY_RUN=false
BACKUP=false
INTERACTIVE=false
VERBOSE=false
FILES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -b|--backup)
            BACKUP=true
            shift
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
        *)
            FILES+=("$1")
            shift
            ;;
    esac
done

# Check if files were provided
if [[ ${#FILES[@]} -eq 0 ]]; then
    echo -e "${RED}Error: No files specified${NC}"
    usage
    exit 1
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
    echo -e "${RED}[ERROR]${NC} $*"
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $*"
    fi
}

# Check if a line needs platform_compat.sh
needs_compat() {
    local line="$1"
    
    # Patterns that indicate platform-specific code
    local patterns=(
        'uname -s'
        'uname -m'
        'nproc'
        'sysctl.*hw.ncpu'
        'command -v'
        'which '
        'mkdir -p'
        'rm -rf'
        'mktemp'
        '/tmp/.*\$\$'
        'curl.*-o'
        'wget.*-O'
        '\033\[.*m'  # Color codes
    )
    
    for pattern in "${patterns[@]}"; do
        if echo "$line" | grep -qE "$pattern"; then
            return 0
        fi
    done
    
    return 1
}

# Suggest replacement for a line
suggest_replacement() {
    local line="$1"
    local suggestion=""
    
    # Platform detection
    if echo "$line" | grep -q 'uname -s'; then
        suggestion="Use detect_os() instead of uname -s"
    elif echo "$line" | grep -q 'uname -m'; then
        suggestion="Use detect_architecture() instead of uname -m"
    # CPU cores
    elif echo "$line" | grep -qE 'nproc|sysctl.*hw.ncpu'; then
        suggestion="Use get_cpu_cores() for cross-platform CPU detection"
    # Command detection
    elif echo "$line" | grep -q 'command -v'; then
        suggestion="Use command_exists() or find_executable()"
    elif echo "$line" | grep -q 'which '; then
        suggestion="Use find_executable() instead of which"
    # File operations
    elif echo "$line" | grep -q 'mkdir -p'; then
        suggestion="Use make_directory() for cross-platform directory creation"
    elif echo "$line" | grep -q 'rm -rf'; then
        suggestion="Use remove_directory() for cross-platform directory removal"
    # Temp files
    elif echo "$line" | grep -qE 'mktemp|/tmp/.*\$\$'; then
        suggestion="Use make_temp_file() or make_temp_dir()"
    # Downloads
    elif echo "$line" | grep -qE 'curl.*-o|wget.*-O'; then
        suggestion="Use download_file() for cross-platform downloads"
    # Colors
    elif echo "$line" | grep -q '\033\[.*m'; then
        suggestion="Use COLOR_* variables or logging functions"
    fi
    
    echo "$suggestion"
}

# Check if script already uses platform_compat.sh
uses_compat() {
    local file="$1"
    grep -q "platform_compat.sh" "$file" 2>/dev/null
}

# Add source line for platform_compat.sh
add_compat_source() {
    local file="$1"
    local temp_file=$(mktemp)
    local added=false
    
    # Read file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        echo "$line" >> "$temp_file"
        
        # Add source after shebang and initial comments
        if [[ "$added" == false ]] && [[ "$line" =~ ^#!/ || "$line" =~ ^# ]] && [[ ! "$line" =~ ^#! ]]; then
            # Check if next line is not a comment
            if ! head -n 1 | grep -q '^#'; then
                echo "" >> "$temp_file"
                echo "# Source platform compatibility layer" >> "$temp_file"
                echo 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"' >> "$temp_file"
                echo 'source "${SCRIPT_DIR}/utils/platform_compat.sh"' >> "$temp_file"
                echo "" >> "$temp_file"
                added=true
            fi
        fi
    done < "$file"
    
    # If not added yet (file has no shebang), add at beginning
    if [[ "$added" == false ]]; then
        {
            echo '#!/usr/bin/env bash'
            echo ""
            echo "# Source platform compatibility layer"
            echo 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
            echo 'source "${SCRIPT_DIR}/utils/platform_compat.sh"'
            echo ""
            cat "$temp_file"
        } > "$temp_file.new"
        mv "$temp_file.new" "$temp_file"
    fi
    
    echo "$temp_file"
}

# Analyze script for migration opportunities
analyze_script() {
    local file="$1"
    local issues=()
    local line_num=0
    
    log_info "Analyzing $file..."
    
    # Check if already uses compat
    if uses_compat "$file"; then
        log_warning "$file already uses platform_compat.sh"
        return 1
    fi
    
    # Analyze each line
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        
        if needs_compat "$line"; then
            local suggestion=$(suggest_replacement "$line")
            if [[ -n "$suggestion" ]]; then
                issues+=("Line $line_num: $suggestion")
                log_verbose "Line $line_num: $line"
                log_verbose "  -> $suggestion"
            fi
        fi
    done < "$file"
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        log_info "No platform-specific code found in $file"
        return 1
    fi
    
    log_info "Found ${#issues[@]} migration opportunities:"
    for issue in "${issues[@]}"; do
        echo "  - $issue"
    done
    
    return 0
}

# Process a single file
process_file() {
    local file="$1"
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    # Check if it's a bash script
    if ! head -n 1 "$file" | grep -qE '^#!/.*(bash|sh)'; then
        log_warning "$file doesn't appear to be a bash script"
        return 1
    fi
    
    # Analyze the script
    if ! analyze_script "$file"; then
        return 0
    fi
    
    # Ask for confirmation if interactive
    if [[ "$INTERACTIVE" == true ]]; then
        echo -n "Migrate $file? [y/N] "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Skipping $file"
            return 0
        fi
    fi
    
    # Create backup if requested
    if [[ "$BACKUP" == true ]]; then
        cp "$file" "$file.bak"
        log_info "Created backup: $file.bak"
    fi
    
    # Add platform_compat.sh source
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would add platform_compat.sh source to $file"
        log_info "[DRY RUN] Manual migration would be needed for platform-specific code"
    else
        local temp_file=$(add_compat_source "$file")
        mv "$temp_file" "$file"
        log_success "Added platform_compat.sh source to $file"
        log_warning "Manual migration needed for platform-specific code"
        log_info "Run 'diff $file.bak $file' to see changes (if backup was created)"
    fi
}

# Main execution
main() {
    log_info "Platform Compatibility Migration Tool"
    log_info "====================================="
    
    # Check if platform_compat.sh exists
    if [[ ! -f "$COMPAT_LIB" ]]; then
        log_error "platform_compat.sh not found at: $COMPAT_LIB"
        exit 1
    fi
    
    # Process each file
    local processed=0
    local migrated=0
    
    for file in "${FILES[@]}"; do
        # Expand globs
        for expanded_file in $file; do
            if [[ -f "$expanded_file" ]]; then
                ((processed++))
                if process_file "$expanded_file"; then
                    ((migrated++))
                fi
                echo ""
            fi
        done
    done
    
    # Summary
    log_info "Summary"
    log_info "======="
    log_info "Files processed: $processed"
    log_info "Files migrated: $migrated"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "This was a dry run. No files were modified."
    fi
}

# Run main
main