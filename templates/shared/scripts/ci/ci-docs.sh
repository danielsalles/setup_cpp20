#!/bin/bash

# {{ project_name }} CI Documentation Script
# Generate and deploy project documentation

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly BUILD_DIR="${PROJECT_ROOT}/build"
readonly DOCS_DIR="${BUILD_DIR}/docs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# CI Environment Detection
detect_ci_environment() {
    if [[ -n "${CI:-}" ]]; then
        echo "ci"
    else
        echo "local"
    fi
}

readonly CI_ENVIRONMENT=$(detect_ci_environment)

# Disable colors in CI unless forced
if [[ "$CI_ENVIRONMENT" != "local" ]] && [[ "${FORCE_COLOR:-false}" != "true" ]]; then
    RED="" GREEN="" YELLOW="" BLUE="" CYAN="" BOLD="" NC=""
fi

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_section() { echo -e "${CYAN}${BOLD}=== $* ===${NC}"; }

# Check if generate_docs.sh exists and use it
generate_documentation() {
    log_section "Generating documentation"
    
    local generate_docs_script="$(dirname "$SCRIPT_DIR")/generate_docs.sh"
    
    if [[ -x "$generate_docs_script" ]]; then
        log_info "Using existing generate_docs.sh script"
        
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "DRY RUN: Would run generate_docs.sh"
            return 0
        fi
        
        if "$generate_docs_script" --output-dir "$DOCS_DIR"; then
            log_success "Documentation generated successfully"
            return 0
        else
            log_error "Documentation generation failed"
            return 1
        fi
    else
        log_warning "generate_docs.sh not found, using basic documentation generation"
        
        mkdir -p "$DOCS_DIR"
        
        # Create basic documentation structure
        cat > "$DOCS_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>{{ project_name }} Documentation</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>{{ project_name }} Documentation</h1>
    <p>This is the generated documentation for {{ project_name }}.</p>
    <p>Generated on: <span id="date"></span></p>
    <script>
        document.getElementById('date').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF
        
        log_success "Basic documentation generated"
        return 0
    fi
}

print_usage() {
    cat << EOF
${BOLD}{{ project_name }} CI Documentation Script${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    --output-dir DIR            Output directory for documentation
    -n, --dry-run               Show what would be done
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EOF
}

# Default values
OUTPUT_DIR="$DOCS_DIR"
DRY_RUN="false"
VERBOSE="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        -n|--dry-run) DRY_RUN="true"; shift ;;
        -v|--verbose) VERBOSE="true"; shift ;;
        -h|--help) print_usage; exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# Update docs directory if custom output specified
if [[ "$OUTPUT_DIR" != "$DOCS_DIR" ]]; then
    DOCS_DIR="$OUTPUT_DIR"
fi

main() {
    cd "$PROJECT_ROOT"
    
    log_info "Starting {{ project_name }} documentation generation..."
    
    if generate_documentation; then
        log_success "{{ project_name }} documentation completed!"
        log_info "Documentation available at: $DOCS_DIR"
    else
        log_error "{{ project_name }} documentation failed!"
        exit 1
    fi
}

main "$@"