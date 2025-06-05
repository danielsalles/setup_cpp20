#!/bin/bash

# {{ project_name }} CI Build Script
# Optimized build script for Continuous Integration environments

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly BUILD_DIR="${PROJECT_ROOT}/build"
readonly CI_REPORTS_DIR="${BUILD_DIR}/ci-reports"

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
    elif [[ -n "${JENKINS_URL:-}" ]]; then
        echo "jenkins"
    elif [[ -n "${CIRCLECI:-}" ]]; then
        echo "circleci"
    elif [[ -n "${TRAVIS:-}" ]]; then
        echo "travis"
    elif [[ -n "${APPVEYOR:-}" ]]; then
        echo "appveyor"
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

# CI-optimized logging functions
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

# CI-specific logging for GitHub Actions
github_actions_log() {
    local level="$1"
    shift
    case "$level" in
        "error")
            echo "::error::$*"
            ;;
        "warning")
            echo "::warning::$*"
            ;;
        "notice")
            echo "::notice::$*"
            ;;
        "group")
            echo "::group::$*"
            ;;
        "endgroup")
            echo "::endgroup::"
            ;;
    esac
}

# Start a collapsible section in CI
start_section() {
    local title="$1"
    case "$CI_ENVIRONMENT" in
        "github-actions")
            github_actions_log "group" "$title"
            ;;
        "gitlab-ci")
            echo -e "\e[0Ksection_start:$(date +%s):${title// /_}[collapsed=true]\r\e[0K$title"
            ;;
        *)
            log_section "$title"
            ;;
    esac
}

# End a collapsible section in CI
end_section() {
    local title="$1"
    case "$CI_ENVIRONMENT" in
        "github-actions")
            github_actions_log "endgroup"
            ;;
        "gitlab-ci")
            echo -e "\e[0Ksection_end:$(date +%s):${title// /_}\r\e[0K"
            ;;
    esac
}

# Check if tools are available
check_prerequisites() {
    local required_tools=("cmake" "ninja" "git")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    log_debug "All prerequisites available"
    return 0
}

# Detect and setup vcpkg
setup_vcpkg() {
    start_section "Setting up vcpkg"
    
    # Try to find vcpkg in common locations
    local vcpkg_paths=(
        "${VCPKG_ROOT:-}"
        "$HOME/.vcpkg"
        "/opt/vcpkg"
        "./vcpkg"
        "../vcpkg"
    )
    
    for vcpkg_path in "${vcpkg_paths[@]}"; do
        if [[ -n "$vcpkg_path" ]] && [[ -d "$vcpkg_path" ]] && [[ -f "$vcpkg_path/scripts/buildsystems/vcpkg.cmake" ]]; then
            export VCPKG_ROOT="$vcpkg_path"
            log_info "Found vcpkg at: $VCPKG_ROOT"
            end_section "Setting up vcpkg"
            return 0
        fi
    done
    
    log_warning "vcpkg not found, proceeding without dependency management"
    end_section "Setting up vcpkg"
}

# Configure build environment for CI
setup_ci_environment() {
    start_section "Setting up CI environment"
    
    # Create directories
    mkdir -p "$BUILD_DIR" "$CI_REPORTS_DIR"
    
    # Set CI-specific environment variables
    export CMAKE_BUILD_PARALLEL_LEVEL="${PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 4)}"
    export MAKEFLAGS="-j${PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 4)}"
    
    # CI-specific compiler settings
    if [[ "$CI_ENVIRONMENT" != "local" ]]; then
        export CCACHE_DISABLE=1  # Disable ccache in CI for reproducible builds
        export CMAKE_DISABLE_FIND_PACKAGE_ccache=ON
    fi
    
    log_info "CI Environment: $CI_ENVIRONMENT"
    log_info "OS: $OS_TYPE ($ARCH_TYPE)"
    log_info "Parallel Jobs: $CMAKE_BUILD_PARALLEL_LEVEL"
    
    end_section "Setting up CI environment"
}

# Configure the project
configure_project() {
    start_section "Configuring project"
    
    cd "$BUILD_DIR"
    
    local cmake_args=(
        -G "${GENERATOR:-Ninja}"
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE:-Release}"
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
    )
    
    # Add vcpkg toolchain if available
    if [[ -n "${VCPKG_ROOT:-}" ]] && [[ -f "$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" ]]; then
        cmake_args+=(-DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake")
        log_info "Using vcpkg toolchain"
    fi
    
    # CI-specific build options
    cmake_args+=(
        -DBUILD_TESTS="${BUILD_TESTS:-ON}"
        -DBUILD_EXAMPLES="${BUILD_EXAMPLES:-OFF}"
    )
    
    # Enable coverage for Debug builds in CI
    if [[ "${BUILD_TYPE:-Release}" == "Debug" ]] && [[ "${ENABLE_COVERAGE:-true}" == "true" ]]; then
        cmake_args+=(
            -DENABLE_COVERAGE=ON
            -DCMAKE_CXX_FLAGS="--coverage -g -O0"
            -DCMAKE_EXE_LINKER_FLAGS="--coverage"
        )
        log_info "Code coverage enabled"
    fi
    
    # Enable static analysis in CI
    if [[ "${ENABLE_STATIC_ANALYSIS:-true}" == "true" ]]; then
        cmake_args+=(
            -DENABLE_CLANG_TIDY=ON
        )
        log_info "Static analysis enabled"
    fi
    
    # Add custom cmake args
    if [[ -n "${CUSTOM_CMAKE_ARGS:-}" ]]; then
        eval "cmake_args+=($CUSTOM_CMAKE_ARGS)"
    fi
    
    log_info "Configuring with: cmake ${cmake_args[*]} $PROJECT_ROOT"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would execute cmake configuration"
        end_section "Configuring project"
        return 0
    fi
    
    if ! cmake "${cmake_args[@]}" "$PROJECT_ROOT"; then
        log_error "CMake configuration failed"
        end_section "Configuring project"
        return 1
    fi
    
    log_success "Project configured successfully"
    end_section "Configuring project"
}

# Build the project
build_project() {
    start_section "Building project"
    
    cd "$BUILD_DIR"
    
    local build_args=(
        --build .
        --config "${BUILD_TYPE:-Release}"
        --parallel "${PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 4)}"
    )
    
    # Add target if specified
    if [[ -n "${BUILD_TARGET:-}" ]]; then
        build_args+=(--target "$BUILD_TARGET")
    fi
    
    # Verbose output for CI
    if [[ "${VERBOSE:-false}" == "true" ]] || [[ "$CI_ENVIRONMENT" != "local" ]]; then
        build_args+=(--verbose)
    fi
    
    log_info "Building with: cmake ${build_args[*]}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would execute cmake build"
        end_section "Building project"
        return 0
    fi
    
    # Capture build output for analysis
    local build_log="$CI_REPORTS_DIR/build.log"
    
    if cmake "${build_args[@]}" 2>&1 | tee "$build_log"; then
        log_success "Build completed successfully"
        
        # Check for warnings
        local warning_count
        warning_count=$(grep -c "warning:" "$build_log" 2>/dev/null || echo 0)
        if [[ $warning_count -gt 0 ]]; then
            log_warning "Build completed with $warning_count warnings"
            if [[ "$CI_ENVIRONMENT" == "github-actions" ]]; then
                github_actions_log "warning" "Build completed with $warning_count warnings"
            fi
        fi
        
        end_section "Building project"
        return 0
    else
        log_error "Build failed"
        
        # Extract and report error details
        if [[ -f "$build_log" ]]; then
            local error_count
            error_count=$(grep -c "error:" "$build_log" 2>/dev/null || echo 0)
            log_error "Build failed with $error_count errors"
            
            # Show last few errors for quick diagnosis
            log_info "Last 10 lines of build output:"
            tail -10 "$build_log" || true
        fi
        
        end_section "Building project"
        return 1
    fi
}

# Run tests if enabled
run_tests() {
    if [[ "${BUILD_TESTS:-ON}" != "ON" ]] || [[ "${RUN_TESTS:-true}" != "true" ]]; then
        log_info "Tests disabled, skipping test execution"
        return 0
    fi
    
    start_section "Running tests"
    
    cd "$BUILD_DIR"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would execute tests"
        end_section "Running tests"
        return 0
    fi
    
    # Check if tests exist
    if ! find . -name "*test*" -executable -type f | head -1 | grep -q .; then
        if [[ ! -f "CTestTestfile.cmake" ]]; then
            log_warning "No tests found to execute"
            end_section "Running tests"
            return 0
        fi
    fi
    
    local test_args=(
        --output-on-failure
        --parallel "${PARALLEL_JOBS:-4}"
    )
    
    # Generate test reports
    if [[ "${GENERATE_TEST_REPORTS:-true}" == "true" ]]; then
        test_args+=(
            --output-junit "$CI_REPORTS_DIR/test-results.xml"
        )
    fi
    
    log_info "Running tests with: ctest ${test_args[*]}"
    
    local test_log="$CI_REPORTS_DIR/test.log"
    
    if ctest "${test_args[@]}" 2>&1 | tee "$test_log"; then
        log_success "All tests passed"
        end_section "Running tests"
        return 0
    else
        log_error "Some tests failed"
        
        # Show failed test details
        if [[ -f "$test_log" ]]; then
            log_info "Failed test summary:"
            grep -A 5 -B 5 "FAILED" "$test_log" || true
        fi
        
        end_section "Running tests"
        return 1
    fi
}

# Generate coverage report
generate_coverage() {
    if [[ "${BUILD_TYPE:-Release}" != "Debug" ]] || [[ "${ENABLE_COVERAGE:-false}" != "true" ]]; then
        return 0
    fi
    
    start_section "Generating coverage report"
    
    cd "$BUILD_DIR"
    
    if ! command -v gcov >/dev/null 2>&1 && ! command -v llvm-cov >/dev/null 2>&1; then
        log_warning "No coverage tools found, skipping coverage report"
        end_section "Generating coverage report"
        return 0
    fi
    
    # Generate coverage data
    if command -v gcovr >/dev/null 2>&1; then
        log_info "Generating coverage report with gcovr"
        
        gcovr \
            --root "$PROJECT_ROOT" \
            --exclude-unreachable-branches \
            --exclude-directories "build" \
            --exclude-directories "tests" \
            --xml "$CI_REPORTS_DIR/coverage.xml" \
            --html "$CI_REPORTS_DIR/coverage.html" \
            --txt "$CI_REPORTS_DIR/coverage.txt" \
            . || log_warning "Coverage report generation failed"
    else
        log_warning "gcovr not found, install it for coverage reports"
    fi
    
    end_section "Generating coverage report"
}

# Install artifacts
install_project() {
    if [[ "${INSTALL_PROJECT:-false}" != "true" ]]; then
        return 0
    fi
    
    start_section "Installing project"
    
    cd "$BUILD_DIR"
    
    local install_args=(
        --install .
        --config "${BUILD_TYPE:-Release}"
    )
    
    if [[ -n "${INSTALL_PREFIX:-}" ]]; then
        install_args+=(--prefix "$INSTALL_PREFIX")
    fi
    
    log_info "Installing with: cmake ${install_args[*]}"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would execute cmake install"
        end_section "Installing project"
        return 0
    fi
    
    if cmake "${install_args[@]}"; then
        log_success "Project installed successfully"
    else
        log_error "Installation failed"
        end_section "Installing project"
        return 1
    fi
    
    end_section "Installing project"
}

# Generate CI summary
generate_ci_summary() {
    start_section "Generating CI summary"
    
    local summary_file="$CI_REPORTS_DIR/ci-summary.md"
    
    {
        echo "# {{ project_name }} CI Build Summary"
        echo
        echo "**Build Date:** $(date)"
        echo "**CI Environment:** $CI_ENVIRONMENT"
        echo "**OS:** $OS_TYPE ($ARCH_TYPE)"
        echo "**Build Type:** ${BUILD_TYPE:-Release}"
        echo
        
        if [[ -f "$CI_REPORTS_DIR/build.log" ]]; then
            local warning_count error_count
            warning_count=$(grep -c "warning:" "$CI_REPORTS_DIR/build.log" 2>/dev/null || echo 0)
            error_count=$(grep -c "error:" "$CI_REPORTS_DIR/build.log" 2>/dev/null || echo 0)
            
            echo "## Build Results"
            echo "- **Warnings:** $warning_count"
            echo "- **Errors:** $error_count"
            echo
        fi
        
        if [[ -f "$CI_REPORTS_DIR/test.log" ]]; then
            echo "## Test Results"
            if grep -q "tests passed" "$CI_REPORTS_DIR/test.log"; then
                echo "✅ All tests passed"
            else
                echo "❌ Some tests failed"
            fi
            echo
        fi
        
        if [[ -f "$CI_REPORTS_DIR/coverage.txt" ]]; then
            echo "## Coverage Report"
            echo "```"
            cat "$CI_REPORTS_DIR/coverage.txt"
            echo "```"
            echo
        fi
        
        echo "## Generated Files"
        if [[ -d "$CI_REPORTS_DIR" ]]; then
            find "$CI_REPORTS_DIR" -type f -name "*.xml" -o -name "*.html" -o -name "*.log" | while read -r file; do
                echo "- $(basename "$file")"
            done
        fi
        
    } > "$summary_file"
    
    log_info "CI summary generated: $summary_file"
    
    # Show summary for quick review
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo
        cat "$summary_file"
    fi
    
    end_section "Generating CI summary"
}

# Print usage information
print_usage() {
    cat << EOF
${BOLD}{{ project_name }} CI Build Script${NC}
Optimized build script for Continuous Integration environments

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}BUILD OPTIONS:${NC}
    --build-type TYPE           Build type: Debug, Release, RelWithDebInfo (default: Release)
    --generator GEN             CMake generator (default: Ninja)
    --target TARGET             Specific build target
    --cmake-args "ARGS"         Additional CMake arguments
    -j, --jobs N                Number of parallel build jobs

${BOLD}FEATURE OPTIONS:${NC}
    --enable-tests              Build and run tests (default: on)
    --disable-tests             Skip building and running tests
    --enable-coverage           Enable code coverage (Debug builds only)
    --enable-static-analysis    Enable static analysis tools
    --enable-install            Install the project after building

${BOLD}CI OPTIONS:${NC}
    --generate-reports          Generate CI reports (default: on)
    --reports-dir DIR           Directory for CI reports (default: build/ci-reports)
    --force-color               Force colored output in CI

${BOLD}BEHAVIOR OPTIONS:${NC}
    -n, --dry-run               Show what would be done without executing
    -v, --verbose               Enable verbose output
    -q, --quiet                 Suppress non-essential output

${BOLD}UTILITY OPTIONS:${NC}
    -h, --help                  Show this help message

${BOLD}EXAMPLES:${NC}
    $0                                  # Standard CI build
    $0 --build-type Debug --enable-coverage  # Debug build with coverage
    $0 --disable-tests --enable-install      # Build and install without tests
    $0 --dry-run --verbose                   # Preview build steps

${BOLD}CI ENVIRONMENTS:${NC}
    Automatically detects and optimizes for:
    - GitHub Actions
    - GitLab CI
    - Jenkins
    - CircleCI
    - Travis CI
    - AppVeyor
    - Generic CI environments

${BOLD}REPORTS:${NC}
    Generated in build/ci-reports/:
    - build.log         # Build output
    - test.log          # Test output
    - test-results.xml  # JUnit test results
    - coverage.xml/.html # Coverage reports
    - ci-summary.md     # Overall summary

EOF
}

# Default values
BUILD_TYPE="Release"
GENERATOR="Ninja"
BUILD_TARGET=""
CUSTOM_CMAKE_ARGS=""
PARALLEL_JOBS=""
BUILD_TESTS="ON"
RUN_TESTS="true"
ENABLE_COVERAGE="false"
ENABLE_STATIC_ANALYSIS="false"
INSTALL_PROJECT="false"
GENERATE_TEST_REPORTS="true"
REPORTS_DIR=""
FORCE_COLOR="false"
DRY_RUN="false"
VERBOSE="false"
QUIET="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        --generator)
            GENERATOR="$2"
            shift 2
            ;;
        --target)
            BUILD_TARGET="$2"
            shift 2
            ;;
        --cmake-args)
            CUSTOM_CMAKE_ARGS="$2"
            shift 2
            ;;
        -j|--jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --enable-tests)
            BUILD_TESTS="ON"
            RUN_TESTS="true"
            shift
            ;;
        --disable-tests)
            BUILD_TESTS="OFF"
            RUN_TESTS="false"
            shift
            ;;
        --enable-coverage)
            ENABLE_COVERAGE="true"
            shift
            ;;
        --enable-static-analysis)
            ENABLE_STATIC_ANALYSIS="true"
            shift
            ;;
        --enable-install)
            INSTALL_PROJECT="true"
            shift
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
    CI_REPORTS_DIR="$REPORTS_DIR"
fi

# Adjust settings for Debug builds
if [[ "$BUILD_TYPE" == "Debug" ]]; then
    ENABLE_COVERAGE="${ENABLE_COVERAGE:-true}"
fi

# Disable output in quiet mode
if [[ "$QUIET" == "true" ]]; then
    exec > >(grep -E "(ERROR|WARNING|SUCCESS)" || true)
fi

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    # Print header
    if [[ "$QUIET" != "true" ]]; then
        log_info "Starting {{ project_name }} CI build..."
        log_info "CI Environment: $CI_ENVIRONMENT"
        echo
    fi
    
    # Execute build pipeline
    local exit_code=0
    
    check_prerequisites || exit_code=1
    [[ $exit_code -eq 0 ]] && setup_vcpkg
    [[ $exit_code -eq 0 ]] && setup_ci_environment
    [[ $exit_code -eq 0 ]] && configure_project || exit_code=1
    [[ $exit_code -eq 0 ]] && build_project || exit_code=1
    [[ $exit_code -eq 0 ]] && run_tests || exit_code=1
    [[ $exit_code -eq 0 ]] && generate_coverage
    [[ $exit_code -eq 0 ]] && install_project
    
    # Always generate summary, even on failure
    generate_ci_summary
    
    # Final status
    if [[ $exit_code -eq 0 ]]; then
        if [[ "$QUIET" != "true" ]]; then
            echo
            log_success "{{ project_name }} CI build completed successfully!"
        fi
    else
        if [[ "$QUIET" != "true" ]]; then
            echo
            log_error "{{ project_name }} CI build failed!"
        fi
    fi
    
    exit $exit_code
}

# Run main function
main "$@"