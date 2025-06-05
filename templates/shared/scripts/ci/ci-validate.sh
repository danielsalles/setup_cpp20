#!/bin/bash

# {{ project_name }} CI Validation Script
# Pre-merge validation including formatting, static analysis, and basic tests

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly BUILD_DIR="${PROJECT_ROOT}/build"
readonly VALIDATION_REPORTS_DIR="${BUILD_DIR}/validation-reports"

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

# Track validation results
declare -A VALIDATION_RESULTS
VALIDATION_RESULTS["format_check"]="PENDING"
VALIDATION_RESULTS["static_analysis"]="PENDING"
VALIDATION_RESULTS["build_check"]="PENDING"
VALIDATION_RESULTS["test_check"]="PENDING"
VALIDATION_RESULTS["security_check"]="PENDING"

# CI-specific logging for GitHub Actions
github_actions_annotation() {
    local level="$1"
    local file="${2:-}"
    local line="${3:-}"
    local message="$4"
    
    local annotation="::${level}"
    if [[ -n "$file" ]]; then
        annotation+=" file=${file}"
        if [[ -n "$line" ]]; then
            annotation+=",line=${line}"
        fi
    fi
    annotation+="::${message}"
    
    echo "$annotation"
}

# Start a validation section
start_validation() {
    local title="$1"
    log_section "$title"
    
    case "$CI_ENVIRONMENT" in
        "github-actions")
            echo "::group::$title"
            ;;
        "gitlab-ci")
            echo -e "\e[0Ksection_start:$(date +%s):${title// /_}[collapsed=true]\r\e[0K$title"
            ;;
    esac
}

# End a validation section
end_validation() {
    local title="$1"
    local result="$2"
    
    case "$CI_ENVIRONMENT" in
        "github-actions")
            echo "::endgroup::"
            if [[ "$result" == "FAILED" ]]; then
                github_actions_annotation "error" "" "" "$title validation failed"
            fi
            ;;
        "gitlab-ci")
            echo -e "\e[0Ksection_end:$(date +%s):${title// /_}\r\e[0K"
            ;;
    esac
}

# Check if required tools are available
check_validation_tools() {
    start_validation "Checking validation tools"
    
    local required_tools=()
    local optional_tools=()
    local missing_required=()
    local missing_optional=()
    
    # Required tools
    if [[ "${CHECK_FORMAT:-true}" == "true" ]]; then
        required_tools+=("clang-format")
    fi
    
    if [[ "${CHECK_BUILD:-true}" == "true" ]]; then
        required_tools+=("cmake" "ninja")
    fi
    
    # Optional tools
    if [[ "${CHECK_STATIC_ANALYSIS:-true}" == "true" ]]; then
        optional_tools+=("clang-tidy")
    fi
    
    if [[ "${CHECK_SECURITY:-false}" == "true" ]]; then
        optional_tools+=("cppcheck")
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
        end_validation "Checking validation tools" "FAILED"
        return 1
    fi
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_warning "Missing optional tools: ${missing_optional[*]}"
        log_info "Some validation checks will be skipped"
    fi
    
    log_success "All required validation tools available"
    end_validation "Checking validation tools" "PASSED"
    return 0
}

# Find source files for validation
find_source_files() {
    local file_patterns=("*.cpp" "*.hpp" "*.cc" "*.hh" "*.cxx" "*.hxx" "*.c++" "*.h++")
    local source_files=()
    
    # Search directories
    local search_dirs=("$PROJECT_ROOT/src" "$PROJECT_ROOT/include" "$PROJECT_ROOT/lib" "$PROJECT_ROOT")
    
    for dir in "${search_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            for pattern in "${file_patterns[@]}"; do
                while IFS= read -r -d '' file; do
                    # Skip build and vendor directories
                    if [[ "$file" =~ /build/ ]] || [[ "$file" =~ /\.git/ ]] || [[ "$file" =~ /vendor/ ]] || [[ "$file" =~ /third_party/ ]]; then
                        continue
                    fi
                    source_files+=("$file")
                done < <(find "$dir" -name "$pattern" -type f -print0 2>/dev/null || true)
            done
        fi
    done
    
    if [[ ${#source_files[@]} -eq 0 ]]; then
        log_warning "No source files found for validation"
        return 1
    fi
    
    log_debug "Found ${#source_files[@]} source files for validation"
    printf '%s\n' "${source_files[@]}"
}

# Check code formatting
check_formatting() {
    if [[ "${CHECK_FORMAT:-true}" != "true" ]]; then
        VALIDATION_RESULTS["format_check"]="SKIPPED"
        return 0
    fi
    
    start_validation "Code formatting check"
    
    if ! command -v clang-format >/dev/null 2>&1; then
        log_warning "clang-format not available, skipping format check"
        VALIDATION_RESULTS["format_check"]="SKIPPED"
        end_validation "Code formatting check" "SKIPPED"
        return 0
    fi
    
    local source_files
    if ! source_files=($(find_source_files)); then
        log_warning "No source files found for format checking"
        VALIDATION_RESULTS["format_check"]="SKIPPED"
        end_validation "Code formatting check" "SKIPPED"
        return 0
    fi
    
    mkdir -p "$VALIDATION_REPORTS_DIR"
    local format_report="$VALIDATION_REPORTS_DIR/format-issues.txt"
    : > "$format_report"
    
    local issues_found=0
    local files_checked=0
    
    log_info "Checking code formatting for ${#source_files[@]} files..."
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would check formatting with clang-format"
        VALIDATION_RESULTS["format_check"]="SKIPPED"
        end_validation "Code formatting check" "SKIPPED"
        return 0
    fi
    
    for file in "${source_files[@]}"; do
        ((files_checked++))
        
        if [[ "${QUIET:-false}" != "true" ]]; then
            printf "\r${BLUE}[INFO]${NC} Checking file %d/%d: %s" "$files_checked" "${#source_files[@]}" "$(basename "$file")"
        fi
        
        # Check if file needs formatting
        if ! clang-format --dry-run --Werror "$file" >/dev/null 2>&1; then
            ((issues_found++))
            echo "Format issue in: $file" >> "$format_report"
            
            if [[ "$CI_ENVIRONMENT" == "github-actions" ]]; then
                github_actions_annotation "error" "$file" "" "Code formatting issue"
            fi
            
            # Show diff if requested
            if [[ "${SHOW_FORMAT_DIFF:-false}" == "true" ]]; then
                echo "--- Expected format for $file ---" >> "$format_report"
                clang-format "$file" >> "$format_report" 2>/dev/null || true
                echo "" >> "$format_report"
            fi
        fi
    done
    
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo  # New line after progress
    fi
    
    if [[ $issues_found -eq 0 ]]; then
        log_success "All $files_checked files are properly formatted"
        VALIDATION_RESULTS["format_check"]="PASSED"
        end_validation "Code formatting check" "PASSED"
        return 0
    else
        log_error "Found formatting issues in $issues_found files"
        log_info "Format report: $format_report"
        
        if [[ "${FIX_FORMAT:-false}" == "true" ]]; then
            log_info "Applying automatic formatting fixes..."
            for file in "${source_files[@]}"; do
                clang-format -i "$file" 2>/dev/null || true
            done
            log_info "Formatting fixes applied. Please review and commit changes."
        fi
        
        VALIDATION_RESULTS["format_check"]="FAILED"
        end_validation "Code formatting check" "FAILED"
        return 1
    fi
}

# Run static analysis
run_static_analysis() {
    if [[ "${CHECK_STATIC_ANALYSIS:-true}" != "true" ]]; then
        VALIDATION_RESULTS["static_analysis"]="SKIPPED"
        return 0
    fi
    
    start_validation "Static analysis"
    
    # Use the existing analyze.sh script if available
    local analyze_script="$(dirname "$SCRIPT_DIR")/analyze.sh"
    
    if [[ -x "$analyze_script" ]]; then
        log_info "Running static analysis with analyze.sh..."
        
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "DRY RUN: Would run static analysis"
            VALIDATION_RESULTS["static_analysis"]="SKIPPED"
            end_validation "Static analysis" "SKIPPED"
            return 0
        fi
        
        # Run analysis with CI-appropriate settings
        local analysis_args=(
            --quiet
            --format=text
            --output-dir="$VALIDATION_REPORTS_DIR"
        )
        
        if [[ "${INCREMENTAL_ANALYSIS:-false}" == "true" ]]; then
            analysis_args+=(--incremental)
        fi
        
        if "$analyze_script" "${analysis_args[@]}"; then
            log_success "Static analysis completed without issues"
            VALIDATION_RESULTS["static_analysis"]="PASSED"
            end_validation "Static analysis" "PASSED"
            return 0
        else
            log_error "Static analysis found issues"
            VALIDATION_RESULTS["static_analysis"]="FAILED"
            end_validation "Static analysis" "FAILED"
            return 1
        fi
    else
        log_warning "analyze.sh not found, skipping static analysis"
        VALIDATION_RESULTS["static_analysis"]="SKIPPED"
        end_validation "Static analysis" "SKIPPED"
        return 0
    fi
}

# Quick build validation
validate_build() {
    if [[ "${CHECK_BUILD:-true}" != "true" ]]; then
        VALIDATION_RESULTS["build_check"]="SKIPPED"
        return 0
    fi
    
    start_validation "Build validation"
    
    if ! command -v cmake >/dev/null 2>&1; then
        log_warning "CMake not available, skipping build validation"
        VALIDATION_RESULTS["build_check"]="SKIPPED"
        end_validation "Build validation" "SKIPPED"
        return 0
    fi
    
    local validation_build_dir="$BUILD_DIR/validation"
    mkdir -p "$validation_build_dir"
    cd "$validation_build_dir"
    
    log_info "Performing quick build validation..."
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would validate build configuration"
        VALIDATION_RESULTS["build_check"]="SKIPPED"
        end_validation "Build validation" "SKIPPED"
        return 0
    fi
    
    # Quick configuration check
    local cmake_args=(
        -G "${GENERATOR:-Ninja}"
        -DCMAKE_BUILD_TYPE=Debug
        -DBUILD_TESTS=ON
    )
    
    # Add vcpkg if available
    if [[ -n "${VCPKG_ROOT:-}" ]] && [[ -f "$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" ]]; then
        cmake_args+=(-DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake")
    fi
    
    local build_log="$VALIDATION_REPORTS_DIR/build-validation.log"
    
    if cmake "${cmake_args[@]}" "$PROJECT_ROOT" >"$build_log" 2>&1; then
        log_success "Build configuration is valid"
        VALIDATION_RESULTS["build_check"]="PASSED"
        end_validation "Build validation" "PASSED"
        return 0
    else
        log_error "Build configuration failed"
        log_info "Build log: $build_log"
        
        # Show last few lines of error
        if [[ -f "$build_log" ]]; then
            log_info "Last 5 lines of build log:"
            tail -5 "$build_log" | while read -r line; do
                log_error "$line"
            done
        fi
        
        VALIDATION_RESULTS["build_check"]="FAILED"
        end_validation "Build validation" "FAILED"
        return 1
    fi
}

# Quick test validation
validate_tests() {
    if [[ "${CHECK_TESTS:-true}" != "true" ]]; then
        VALIDATION_RESULTS["test_check"]="SKIPPED"
        return 0
    fi
    
    start_validation "Test validation"
    
    # Check if we have a valid build directory
    local test_build_dir="$BUILD_DIR/validation"
    if [[ ! -d "$test_build_dir" ]]; then
        log_warning "No build directory for test validation"
        VALIDATION_RESULTS["test_check"]="SKIPPED"
        end_validation "Test validation" "SKIPPED"
        return 0
    fi
    
    cd "$test_build_dir"
    
    log_info "Performing quick test validation...")
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would validate tests"
        VALIDATION_RESULTS["test_check"]="SKIPPED"
        end_validation "Test validation" "SKIPPED"
        return 0
    fi
    
    # Quick build of test targets only
    if command -v ninja >/dev/null 2>&1 && [[ -f "build.ninja" ]]; then
        local test_log="$VALIDATION_REPORTS_DIR/test-validation.log"
        
        # Build test targets
        if ninja -t targets | grep -q test; then
            if ninja $(ninja -t targets | grep test | head -5 | cut -d: -f1) >"$test_log" 2>&1; then
                log_success "Test targets build successfully"
                VALIDATION_RESULTS["test_check"]="PASSED"
                end_validation "Test validation" "PASSED"
                return 0
            else
                log_error "Test targets failed to build"
                VALIDATION_RESULTS["test_check"]="FAILED"
                end_validation "Test validation" "FAILED"
                return 1
            fi
        else
            log_info "No test targets found"
            VALIDATION_RESULTS["test_check"]="SKIPPED"
            end_validation "Test validation" "SKIPPED"
            return 0
        fi
    else
        log_warning "Cannot validate tests without ninja"
        VALIDATION_RESULTS["test_check"]="SKIPPED"
        end_validation "Test validation" "SKIPPED"
        return 0
    fi
}

# Security validation
validate_security() {
    if [[ "${CHECK_SECURITY:-false}" != "true" ]]; then
        VALIDATION_RESULTS["security_check"]="SKIPPED"
        return 0
    fi
    
    start_validation "Security validation"
    
    local security_issues=0
    local security_report="$VALIDATION_REPORTS_DIR/security-issues.txt"
    : > "$security_report"
    
    # Check for common security issues in source files
    local source_files
    if source_files=($(find_source_files)); then
        log_info "Checking for common security issues..."
        
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "DRY RUN: Would check for security issues"
            VALIDATION_RESULTS["security_check"]="SKIPPED"
            end_validation "Security validation" "SKIPPED"
            return 0
        fi
        
        # Common security patterns to check
        local patterns=(
            "strcpy\|strcat\|sprintf\|gets"  # Unsafe C functions
            "system\s*\("                    # System calls
            "eval\s*\("                      # Code evaluation
            "TODO.*[Ss]ecurity"             # Security TODOs
            "FIXME.*[Ss]ecurity"            # Security FIXMEs
        )
        
        for pattern in "${patterns[@]}"; do
            while IFS= read -r match; do
                echo "$match" >> "$security_report"
                ((security_issues++))
            done < <(grep -rn "$pattern" "${source_files[@]}" 2>/dev/null || true)
        done
        
        # Check for hardcoded credentials/keys
        local credential_patterns=(
            "password\s*=\s*[\"'][^\"']*[\"']"
            "api[_-]?key\s*=\s*[\"'][^\"']*[\"']"
            "secret\s*=\s*[\"'][^\"']*[\"']"
            "token\s*=\s*[\"'][^\"']*[\"']"
        )
        
        for pattern in "${credential_patterns[@]}"; do
            while IFS= read -r match; do
                echo "POTENTIAL CREDENTIAL: $match" >> "$security_report"
                ((security_issues++))
            done < <(grep -riP "$pattern" "${source_files[@]}" 2>/dev/null || true)
        done
    fi
    
    if [[ $security_issues -eq 0 ]]; then
        log_success "No obvious security issues found"
        VALIDATION_RESULTS["security_check"]="PASSED"
        end_validation "Security validation" "PASSED"
        return 0
    else
        log_warning "Found $security_issues potential security issues"
        log_info "Security report: $security_report"
        VALIDATION_RESULTS["security_check"]="WARNING"
        end_validation "Security validation" "WARNING"
        return 0  # Don't fail on security warnings
    fi
}

# Generate validation summary
generate_validation_summary() {
    log_section "Validation Summary"
    
    local summary_file="$VALIDATION_REPORTS_DIR/validation-summary.md"
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    local skipped_checks=0
    
    mkdir -p "$VALIDATION_REPORTS_DIR"
    
    {
        echo "# {{ project_name }} Validation Summary"
        echo
        echo "**Validation Date:** $(date)"
        echo "**Environment:** $CI_ENVIRONMENT"
        echo
        echo "## Results"
        echo
    } > "$summary_file"
    
    # Process results
    for check in "${!VALIDATION_RESULTS[@]}"; do
        local result="${VALIDATION_RESULTS[$check]}"
        local status_icon=""
        
        ((total_checks++))
        
        case "$result" in
            "PASSED")
                status_icon="✅"
                ((passed_checks++))
                ;;
            "FAILED")
                status_icon="❌"
                ((failed_checks++))
                ;;
            "WARNING")
                status_icon="⚠️"
                ((passed_checks++))  # Count warnings as passed
                ;;
            "SKIPPED")
                status_icon="⏭️"
                ((skipped_checks++))
                ;;
            *)
                status_icon="❓"
                ;;
        esac
        
        echo "- **$(echo "$check" | tr '_' ' ' | sed 's/\b\w/\U&/g'):** $status_icon $result" >> "$summary_file"
        
        # Console output
        local check_name=$(echo "$check" | tr '_' ' ' | sed 's/\b\w/\U&/g')
        case "$result" in
            "PASSED"|"WARNING")
                log_success "$check_name: $result"
                ;;
            "FAILED")
                log_error "$check_name: $result"
                ;;
            *)
                log_info "$check_name: $result"
                ;;
        esac
    done
    
    {
        echo
        echo "## Summary Statistics"
        echo "- **Total Checks:** $total_checks"
        echo "- **Passed:** $passed_checks"
        echo "- **Failed:** $failed_checks"
        echo "- **Skipped:** $skipped_checks"
        echo
        
        if [[ $failed_checks -eq 0 ]]; then
            echo "🎉 **All validation checks passed!**"
        else
            echo "❌ **Validation failed with $failed_checks issues**"
        fi
        
        echo
        echo "## Generated Reports"
        find "$VALIDATION_REPORTS_DIR" -name "*.txt" -o -name "*.log" | while read -r file; do
            echo "- [$(basename "$file")]($file)"
        done
        
    } >> "$summary_file"
    
    log_info "Validation summary: $summary_file"
    
    # Return exit code based on results
    if [[ $failed_checks -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Print usage information
print_usage() {
    cat << EOF
${BOLD}{{ project_name }} CI Validation Script${NC}
Pre-merge validation including formatting, static analysis, and basic tests

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}VALIDATION OPTIONS:${NC}
    --check-format              Check code formatting with clang-format (default: on)
    --no-format                 Skip formatting check
    --check-static-analysis     Run static analysis with clang-tidy (default: on)
    --no-static-analysis        Skip static analysis
    --check-build               Validate build configuration (default: on)
    --no-build                  Skip build validation
    --check-tests               Validate test targets (default: on)
    --no-tests                  Skip test validation
    --check-security            Run basic security checks (default: off)

${BOLD}FORMATTING OPTIONS:${NC}
    --fix-format                Automatically fix formatting issues
    --show-format-diff          Show formatting differences in reports

${BOLD}ANALYSIS OPTIONS:${NC}
    --incremental-analysis      Only analyze changed files
    --generator GEN             CMake generator for build validation

${BOLD}OUTPUT OPTIONS:${NC}
    --reports-dir DIR           Directory for validation reports
    --force-color               Force colored output in CI

${BOLD}BEHAVIOR OPTIONS:${NC}
    -n, --dry-run               Show what would be done without executing
    -v, --verbose               Enable verbose output
    -q, --quiet                 Suppress non-essential output

${BOLD}UTILITY OPTIONS:${NC}
    -h, --help                  Show this help message

${BOLD}EXAMPLES:${NC}
    $0                                  # Run all validation checks
    $0 --no-build --no-tests            # Only format and static analysis
    $0 --fix-format --check-security    # Fix formatting and check security
    $0 --dry-run --verbose              # Preview validation steps

${BOLD}VALIDATION CHECKS:${NC}
    1. Code Formatting      - Ensures consistent code style
    2. Static Analysis      - Finds potential bugs and issues
    3. Build Validation     - Verifies project builds correctly
    4. Test Validation      - Checks test targets build
    5. Security Check       - Basic security pattern detection

${BOLD}REPORTS:${NC}
    Generated in build/validation-reports/:
    - validation-summary.md     # Overall summary
    - format-issues.txt         # Formatting problems
    - analysis_report.txt       # Static analysis results
    - build-validation.log      # Build configuration log
    - security-issues.txt       # Security concerns

EOF
}

# Default values
CHECK_FORMAT="true"
CHECK_STATIC_ANALYSIS="true"
CHECK_BUILD="true"
CHECK_TESTS="true"
CHECK_SECURITY="false"
FIX_FORMAT="false"
SHOW_FORMAT_DIFF="false"
INCREMENTAL_ANALYSIS="false"
GENERATOR="Ninja"
REPORTS_DIR=""
FORCE_COLOR="false"
DRY_RUN="false"
VERBOSE="false"
QUIET="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --check-format)
            CHECK_FORMAT="true"
            shift
            ;;
        --no-format)
            CHECK_FORMAT="false"
            shift
            ;;
        --check-static-analysis)
            CHECK_STATIC_ANALYSIS="true"
            shift
            ;;
        --no-static-analysis)
            CHECK_STATIC_ANALYSIS="false"
            shift
            ;;
        --check-build)
            CHECK_BUILD="true"
            shift
            ;;
        --no-build)
            CHECK_BUILD="false"
            shift
            ;;
        --check-tests)
            CHECK_TESTS="true"
            shift
            ;;
        --no-tests)
            CHECK_TESTS="false"
            shift
            ;;
        --check-security)
            CHECK_SECURITY="true"
            shift
            ;;
        --fix-format)
            FIX_FORMAT="true"
            shift
            ;;
        --show-format-diff)
            SHOW_FORMAT_DIFF="true"
            shift
            ;;
        --incremental-analysis)
            INCREMENTAL_ANALYSIS="true"
            shift
            ;;
        --generator)
            GENERATOR="$2"
            shift 2
            ;;
        --reports-dir)
            REPORTS_DIR="$2"
            shift 2
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

# Set reports directory
if [[ -n "$REPORTS_DIR" ]]; then
    VALIDATION_REPORTS_DIR="$REPORTS_DIR"
fi

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    # Print header
    if [[ "$QUIET" != "true" ]]; then
        log_info "Starting {{ project_name }} validation..."
        log_info "Environment: $CI_ENVIRONMENT"
        echo
    fi
    
    # Setup
    mkdir -p "$VALIDATION_REPORTS_DIR"
    
    # Run validation checks
    local validation_failed=false
    
    check_validation_tools || validation_failed=true
    
    if [[ "$validation_failed" != "true" ]]; then
        check_formatting || validation_failed=true
        run_static_analysis || validation_failed=true
        validate_build || validation_failed=true
        validate_tests || validation_failed=true
        validate_security || true  # Don't fail on security warnings
    fi
    
    # Generate summary
    echo
    if generate_validation_summary; then
        if [[ "$QUIET" != "true" ]]; then
            echo
            log_success "{{ project_name }} validation completed successfully!"
        fi
        exit 0
    else
        if [[ "$QUIET" != "true" ]]; then
            echo
            log_error "{{ project_name }} validation failed!"
        fi
        exit 1
    fi
}

# Run main function
main "$@"