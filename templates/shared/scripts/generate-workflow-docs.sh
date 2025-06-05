#!/usr/bin/env bash
set -euo pipefail

# Source compatibility layer if available
source "$(dirname "$0")/utils/platform_compat.sh" 2>/dev/null || {
    # Fallback implementations
    detect_os_type() { uname -s | tr '[:upper:]' '[:lower:]'; }
    log_info() { echo "ℹ️  $*"; }
    log_success() { echo "✅ $*"; }
    log_warning() { echo "⚠️  $*"; }
    log_error() { echo "❌ $*" >&2; }
}

# Script configuration
SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default configuration
PROJECT_NAME="{{ project_name }}"
OUTPUT_DIR="docs/workflow"
FORMAT="html"
QUIET=false
VERBOSE=false

# Show help
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [options]

Generate comprehensive workflow documentation from development scripts.

Options:
    -h, --help              Show this help message
    -v, --version           Show version information
    -o, --output DIR        Output directory (default: docs/workflow)
    -f, --format FORMAT     Output format: html, pdf, confluence (default: html)
    -p, --project NAME      Project name (default: {{ project_name }})
    
    Output Options:
    --quiet                 Suppress non-essential output
    --verbose               Show detailed output
    --open                  Open generated documentation after creation

Examples:
    $SCRIPT_NAME                                    # Generate HTML docs
    $SCRIPT_NAME --format pdf --output build/docs  # Generate PDF
    $SCRIPT_NAME --open                            # Generate and open

Dependencies:
    - pandoc (optional, for enhanced HTML/PDF)
    - graphviz/dot (optional, for dependency graphs)

EOF
}

# Generate documentation
generate_documentation() {
    local output_dir="$1"
    local format="$2"
    
    log_info "Generating $format documentation in $output_dir..."
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Copy main README
    if [[ -f "$SCRIPT_DIR/README.md" ]]; then
        cp "$SCRIPT_DIR/README.md" "$output_dir/workflow.md"
        log_success "Copied main workflow documentation"
    else
        log_error "Main README.md not found at $SCRIPT_DIR/README.md"
        return 1
    fi
    
    # Generate HTML documentation
    local html_file="$output_dir/workflow-documentation.html"
    
    if command -v pandoc >/dev/null 2>&1; then
        log_info "Using pandoc for enhanced HTML conversion..."
        pandoc "$output_dir/workflow.md" \
            --from markdown \
            --to html5 \
            --standalone \
            --toc \
            --toc-depth=3 \
            --highlight-style=github \
            --metadata title="$PROJECT_NAME Development Workflow" \
            --output "$html_file"
        log_success "Generated enhanced HTML documentation: $html_file"
    else
        log_info "Creating basic HTML documentation..."
        cat > "$html_file" << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Development Workflow Documentation</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; 
            max-width: 1200px; 
            margin: 0 auto; 
            padding: 20px; 
            line-height: 1.6;
            color: #333;
        }
        h1, h2, h3 { color: #2c3e50; border-bottom: 2px solid #ecf0f1; padding-bottom: 10px; }
        code { 
            background-color: #f8f9fa; 
            padding: 2px 6px; 
            border-radius: 4px; 
            font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
        }
        pre { 
            background-color: #f8f9fa; 
            padding: 15px; 
            border-radius: 8px; 
            overflow-x: auto; 
            border-left: 4px solid #3498db;
        }
        table { 
            border-collapse: collapse; 
            width: 100%; 
            margin: 20px 0;
        }
        th, td { 
            border: 1px solid #ddd; 
            padding: 12px; 
            text-align: left; 
        }
        th { 
            background-color: #34495e; 
            color: white;
        }
        .toc { 
            background-color: #ecf0f1; 
            padding: 20px; 
            border-radius: 8px; 
            margin-bottom: 30px; 
        }
        .emoji { font-size: 1.2em; }
        a { color: #3498db; text-decoration: none; }
        a:hover { text-decoration: underline; }
        blockquote {
            border-left: 4px solid #3498db;
            margin: 0;
            padding-left: 20px;
            font-style: italic;
        }
    </style>
</head>
<body>
HTML_EOF
        
        # Process markdown content
        awk '
        BEGIN { in_code_block = 0 }
        /^```/ { 
            if (in_code_block) {
                print "</code></pre>"
                in_code_block = 0
            } else {
                print "<pre><code>"
                in_code_block = 1
            }
            next
        }
        !in_code_block && /^# / { 
            gsub(/^# /, "")
            print "<h1>" $0 "</h1>"
            next
        }
        !in_code_block && /^## / { 
            gsub(/^## /, "")
            print "<h2>" $0 "</h2>"
            next
        }
        !in_code_block && /^### / { 
            gsub(/^### /, "")
            print "<h3>" $0 "</h3>"
            next
        }
        !in_code_block && /^\| / {
            if (!in_table) {
                print "<table>"
                in_table = 1
            }
            gsub(/^\| /, "<tr><td>")
            gsub(/ \| /, "</td><td>")
            gsub(/ \|$/, "</td></tr>")
            print
            next
        }
        !in_code_block && !/^\| / && in_table {
            print "</table>"
            in_table = 0
        }
        !in_code_block {
            gsub(/\*\*([^*]+)\*\*/, "<strong>\\1</strong>")
            gsub(/`([^`]+)`/, "<code>\\1</code>")
            if ($0 == "") print "<p></p>"
            else print "<p>" $0 "</p>"
        }
        in_code_block { print }
        END { 
            if (in_code_block) print "</code></pre>"
            if (in_table) print "</table>"
        }
        ' "$output_dir/workflow.md" >> "$html_file"
        
        echo "</body></html>" >> "$html_file"
        log_success "Generated basic HTML documentation: $html_file"
    fi
    
    return 0
}

# Main function
main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "$SCRIPT_NAME version $SCRIPT_VERSION"
                exit 0
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -f|--format)
                FORMAT="$2"
                shift 2
                ;;
            -p|--project)
                PROJECT_NAME="$2"
                shift 2
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --open)
                OPEN_AFTER=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Generate documentation
    if ! generate_documentation "$OUTPUT_DIR" "$FORMAT"; then
        log_error "Failed to generate documentation"
        exit 1
    fi
    
    # Open documentation if requested
    if [[ "${OPEN_AFTER:-false}" == true ]]; then
        local doc_file="$OUTPUT_DIR/workflow-documentation.html"
        
        if [[ -f "$doc_file" ]]; then
            case "$(detect_os_type)" in
                "darwin")
                    open "$doc_file" 2>/dev/null || true
                    ;;
                "linux")
                    xdg-open "$doc_file" 2>/dev/null || true
                    ;;
                *)
                    log_info "Please open: $doc_file"
                    ;;
            esac
            log_info "Documentation available at: $doc_file"
        fi
    fi
    
    log_success "Documentation generation complete!"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Format: $FORMAT"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
