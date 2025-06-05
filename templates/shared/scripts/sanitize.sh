#!/bin/bash

# {{ project_name }} Sanitizers Runner Script
# Run various sanitizers to detect bugs and memory issues

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly BUILD_DIR="${PROJECT_ROOT}/build"

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

log_sanitizer() {
    if [[ "${QUIET:-false}" != true ]]; then
        echo -e "${CYAN}🔬 [SANITIZER]${NC} $*"
    fi
}

# Check if compiler supports sanitizers
check_sanitizer_support() {
    local compiler="$1"
    local sanitizer="$2"
    
    log_debug "Checking $sanitizer support for $compiler..."
    
    # Create a test file
    local test_file="/tmp/sanitizer_test_$$.cpp"
    cat > "$test_file" << 'EOF'
#include <iostream>
int main() {
    std::cout << "Sanitizer test" << std::endl;
    return 0;
}
EOF
    
    # Try to compile with sanitizer
    local sanitizer_flag=""
    case "$sanitizer" in
        asan)
            sanitizer_flag="-fsanitize=address"
            ;;
        ubsan)
            sanitizer_flag="-fsanitize=undefined"
            ;;
        tsan)
            sanitizer_flag="-fsanitize=thread"
            ;;
        msan)
            sanitizer_flag="-fsanitize=memory"
            ;;
    esac
    
    if "$compiler" $sanitizer_flag -std=c++20 "$test_file" -o "/tmp/sanitizer_test_$$" 2>/dev/null; then
        rm -f "$test_file" "/tmp/sanitizer_test_$$"
        return 0
    else
        rm -f "$test_file" "/tmp/sanitizer_test_$$"
        return 1
    fi
}

# Detect available compilers
detect_compilers() {
    local compilers=()
    
    # Check for common C++ compilers
    local candidates=("g++" "clang++" "g++-13" "g++-12" "g++-11" "clang++-17" "clang++-16" "clang++-15")
    
    for compiler in "${candidates[@]}"; do
        if command -v "$compiler" >/dev/null 2>&1; then
            compilers+=("$compiler")
            log_debug "Found compiler: $compiler"
        fi
    done
    
    if [[ ${#compilers[@]} -eq 0 ]]; then
        log_error "No C++ compilers found"
        return 1
    fi
    
    echo "${compilers[@]}"
}

# Select best compiler for sanitizer
select_compiler() {
    local sanitizer="$1"
    local available_compilers=("$@")
    shift  # Remove sanitizer from args
    
    # Preference order: clang++ (better sanitizer support), then g++
    local preferred=("clang++" "clang++-17" "clang++-16" "clang++-15" "g++" "g++-13" "g++-12")
    
    for pref_compiler in "${preferred[@]}"; do
        for available in "${available_compilers[@]}"; do
            if [[ "$available" == "$pref_compiler" ]]; then
                if check_sanitizer_support "$available" "$sanitizer"; then
                    echo "$available"
                    return 0
                fi
            fi
        done
    done
    
    # Fallback: try any available compiler
    for compiler in "${available_compilers[@]}"; do
        if check_sanitizer_support "$compiler" "$sanitizer"; then
            echo "$compiler"
            return 0
        fi
    done
    
    return 1
}

# Build with sanitizer
build_with_sanitizer() {
    local sanitizer="$1"
    local compiler="$2"
    
    log_sanitizer "Building with $sanitizer using $compiler..."
    
    # Create sanitizer-specific build directory
    local sanitizer_build_dir="$BUILD_DIR/sanitizer_$sanitizer"
    mkdir -p "$sanitizer_build_dir"
    cd "$sanitizer_build_dir"
    
    # Prepare CMake arguments for sanitizer
    local cmake_args=(
        -G "${GENERATOR:-Ninja}"
        -DCMAKE_BUILD_TYPE=Debug
        -DCMAKE_CXX_COMPILER="$compiler"
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    )
    
    # Add sanitizer-specific flags
    case "$sanitizer" in
        asan)
            cmake_args+=(
                -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer -O1"
                -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address"
            )
            ;;
        ubsan)
            cmake_args+=(
                -DCMAKE_CXX_FLAGS="-fsanitize=undefined -fno-omit-frame-pointer -O1"
                -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=undefined"
            )
            ;;
        tsan)
            cmake_args+=(
                -DCMAKE_CXX_FLAGS="-fsanitize=thread -fno-omit-frame-pointer -O1"
                -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=thread"
            )
            ;;
        msan)
            cmake_args+=(
                -DCMAKE_CXX_FLAGS="-fsanitize=memory -fno-omit-frame-pointer -O1 -fPIE"
                -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=memory -pie"
            )
            ;;
    esac
    
    # Add vcpkg toolchain if available
    if [[ -n "${VCPKG_ROOT:-}" ]] && [[ -f "$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" ]]; then
        cmake_args+=(-DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake")
    elif [[ -d "$HOME/.vcpkg" ]] && [[ -f "$HOME/.vcpkg/scripts/buildsystems/vcpkg.cmake" ]]; then
        cmake_args+=(-DCMAKE_TOOLCHAIN_FILE="$HOME/.vcpkg/scripts/buildsystems/vcpkg.cmake")
    fi
    
    # Add custom cmake args if provided
    if [[ -n "$CUSTOM_CMAKE_ARGS" ]]; then
        eval "cmake_args+=($CUSTOM_CMAKE_ARGS)"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would configure with: cmake ${cmake_args[*]} $PROJECT_ROOT"
        log_info "Would build with: cmake --build . --parallel ${PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 4)}"
        return 0
    fi
    
    # Configure
    log_debug "Configuring: cmake ${cmake_args[*]} $PROJECT_ROOT"
    if ! cmake "${cmake_args[@]}" "$PROJECT_ROOT"; then
        log_error "Failed to configure with $sanitizer"
        return 1
    fi
    
    # Build
    log_debug "Building with $sanitizer..."
    if ! cmake --build . --parallel "${PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 4)}"; then
        log_error "Failed to build with $sanitizer"
        return 1
    fi
    
    log_success "Built successfully with $sanitizer"
    return 0
}

# Run tests with sanitizer
run_sanitizer_tests() {
    local sanitizer="$1"
    
    local sanitizer_build_dir="$BUILD_DIR/sanitizer_$sanitizer"
    cd "$sanitizer_build_dir"
    
    log_sanitizer "Running tests with $sanitizer..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would run tests with $sanitizer environment"
        return 0
    fi
    
    # Set sanitizer-specific environment variables
    export ASAN_OPTIONS=""
    export UBSAN_OPTIONS=""
    export TSAN_OPTIONS=""
    export MSAN_OPTIONS=""
    
    case "$sanitizer" in
        asan)
            export ASAN_OPTIONS="halt_on_error=1:abort_on_error=1:detect_leaks=1:check_initialization_order=1:strict_init_order=1"
            ;;
        ubsan)
            export UBSAN_OPTIONS="halt_on_error=1:abort_on_error=1:print_stacktrace=1"
            ;;
        tsan)
            export TSAN_OPTIONS="halt_on_error=1:abort_on_error=1:second_deadlock_stack=1"
            ;;
        msan)
            export MSAN_OPTIONS="halt_on_error=1:abort_on_error=1:print_stats=1"
            ;;
    esac
    
    # Look for test executables
    local test_found=false
    local test_results=()
    
    # Try CTest first
    if [[ -f "CTestTestfile.cmake" ]] || [[ -f "Testing/Temporary/CTestCostData.txt" ]]; then
        log_debug "Running CTest with $sanitizer..."
        
        if ctest --output-on-failure --parallel "${PARALLEL_JOBS:-4}"; then
            log_success "CTest passed with $sanitizer"
            test_results+=("CTest: PASSED")
        else
            log_error "CTest failed with $sanitizer"
            test_results+=("CTest: FAILED")
        fi
        test_found=true
    fi
    
    # Look for test executables
    local test_patterns=("*test*" "*Test*" "*TEST*" "test_*" "Test_*" "*_test" "*_Test")
    
    for pattern in "${test_patterns[@]}"; do
        while IFS= read -r -d '' test_exe; do
            if [[ -x "$test_exe" ]]; then
                local test_name
                test_name="$(basename "$test_exe")"
                log_debug "Running test executable: $test_name"
                
                if timeout "${TEST_TIMEOUT:-300}" "$test_exe"; then
                    log_success "Test $test_name passed with $sanitizer"
                    test_results+=("$test_name: PASSED")
                else
                    log_error "Test $test_name failed with $sanitizer"
                    test_results+=("$test_name: FAILED")
                fi
                test_found=true
            fi
        done < <(find . -name "$pattern" -type f -print0 2>/dev/null || true)
    done
    
    if [[ "$test_found" != true ]]; then
        log_warning "No tests found for $sanitizer run"
        
        # Try to run main executable if it exists
        if [[ -f "{{ project_name }}" ]] && [[ -x "{{ project_name }}" ]]; then
            log_debug "Running main executable with $sanitizer..."
            if timeout "${TEST_TIMEOUT:-60}" "./{{ project_name }}"; then
                log_success "Main executable ran successfully with $sanitizer"
                test_results+=("Main executable: PASSED")
            else
                log_warning "Main executable had issues with $sanitizer"
                test_results+=("Main executable: ISSUES")
            fi
        fi
    fi
    
    # Store results
    echo "${test_results[@]}"
}

# Generate sanitizer report
generate_report() {
    local sanitizers_run=("$@")
    
    if [[ "$QUIET" == true ]] || [[ "$NO_REPORT" == true ]]; then
        return
    fi
    
    local report_file="$BUILD_DIR/sanitizer_report.txt"
    
    {
        echo "{{ project_name }} Sanitizer Report"
        echo "Generated on: $(date)"
        echo "=================================="
        echo
        
        for sanitizer in "${sanitizers_run[@]}"; do
            echo "[$sanitizer] Results:"
            
            local results_file="$BUILD_DIR/sanitizer_${sanitizer}_results.txt"
            if [[ -f "$results_file" ]]; then
                cat "$results_file"
            else
                echo "  No results available"
            fi
            echo
        done
        
        echo "Summary:"
        local total_passed=0
        local total_failed=0
        
        for sanitizer in "${sanitizers_run[@]}"; do
            local results_file="$BUILD_DIR/sanitizer_${sanitizer}_results.txt"
            if [[ -f "$results_file" ]]; then
                local passed
                passed=$(grep -c "PASSED" "$results_file" 2>/dev/null || echo 0)
                local failed
                failed=$(grep -c "FAILED" "$results_file" 2>/dev/null || echo 0)
                
                ((total_passed += passed)) || true
                ((total_failed += failed)) || true
                
                echo "  $sanitizer: $passed passed, $failed failed"
            fi
        done
        
        echo "  Total: $total_passed passed, $total_failed failed"
        
    } > "$report_file"
    
    log_info "Sanitizer report generated: $report_file"
    
    if [[ "$VERBOSE" == true ]]; then
        echo
        cat "$report_file"
    fi
}

# Show configuration
show_config() {
    if [[ "$QUIET" == true ]]; then
        return
    fi
    
    log_info "Sanitizer Configuration:"
    echo "  Project: {{ project_name }}"
    echo "  Project Root: $PROJECT_ROOT"
    echo "  Build Directory: $BUILD_DIR"
    echo "  Mode: $([ "$DRY_RUN" == true ] && echo "Dry Run" || echo "Execute")"
    echo "  Parallel Jobs: ${PARALLEL_JOBS:-$(nproc 2>/dev/null || echo 4)}"
    echo "  Test Timeout: ${TEST_TIMEOUT:-300}s"
    echo "  Generator: ${GENERATOR:-Ninja}"
    
    if [[ "$RUN_ASAN" == true ]]; then
        echo "  Address Sanitizer: Enabled"
    fi
    if [[ "$RUN_UBSAN" == true ]]; then
        echo "  UB Sanitizer: Enabled"
    fi
    if [[ "$RUN_TSAN" == true ]]; then
        echo "  Thread Sanitizer: Enabled"
    fi
    if [[ "$RUN_MSAN" == true ]]; then
        echo "  Memory Sanitizer: Enabled"
    fi
}

# Print usage information
print_usage() {
    cat << EOF
${BOLD}{{ project_name }} Sanitizers Runner Script${NC}
Run various sanitizers to detect bugs and memory issues

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}SANITIZER OPTIONS:${NC}
    --all                   Run all available sanitizers (default)
    --asan                  Run Address Sanitizer only
    --ubsan                 Run Undefined Behavior Sanitizer only
    --tsan                  Run Thread Sanitizer only
    --msan                  Run Memory Sanitizer only (clang only)

${BOLD}BUILD OPTIONS:${NC}
    --compiler COMPILER     Use specific compiler (g++, clang++, etc.)
    --generator GEN         CMake generator (Ninja, "Unix Makefiles", etc.)
    --cmake-args "ARGS"     Additional CMake arguments
    -j, --jobs N            Number of parallel build jobs

${BOLD}TEST OPTIONS:${NC}
    --skip-tests            Build with sanitizers but don't run tests
    --timeout SECONDS       Test timeout in seconds (default: 300)
    --no-report             Don't generate summary report

${BOLD}BEHAVIOR OPTIONS:${NC}
    -n, --dry-run           Show what would be done without executing
    -v, --verbose           Enable verbose output with detailed information
    -q, --quiet             Suppress non-essential output
    --color                 Force colored output
    --no-color              Disable colored output

${BOLD}UTILITY OPTIONS:${NC}
    -h, --help              Show this help message

${BOLD}EXAMPLES:${NC}
    $0                              # Run all available sanitizers
    $0 --asan --ubsan               # Run only ASan and UBSan
    $0 --tsan --compiler clang++    # Run TSan with clang++
    $0 --dry-run --verbose          # Preview what would be done
    $0 --skip-tests --asan          # Build with ASan but don't test
    $0 --timeout 600 --all          # Run all with 10-minute timeout

${BOLD}SANITIZERS:${NC}
    ASan:       Address Sanitizer - detects memory errors (use-after-free, etc.)
    UBSan:      Undefined Behavior Sanitizer - detects undefined behavior
    TSan:       Thread Sanitizer - detects data races and deadlocks
    MSan:       Memory Sanitizer - detects uninitialized reads (clang only)

${BOLD}NOTES:${NC}
    - Builds in Debug mode with optimizations for sanitizer effectiveness
    - Each sanitizer uses a separate build directory
    - Reports are generated in build/sanitizer_report.txt
    - Some sanitizers may not be available on all compilers/platforms
    - TSan and ASan cannot be used together
    - MSan requires clang and instrumented libraries

EOF
}

# Default values
RUN_ALL=true
RUN_ASAN=false
RUN_UBSAN=false
RUN_TSAN=false
RUN_MSAN=false
CUSTOM_COMPILER=""
GENERATOR=""
CUSTOM_CMAKE_ARGS=""
PARALLEL_JOBS=""
SKIP_TESTS=false
TEST_TIMEOUT=""
NO_REPORT=false
DRY_RUN=false
VERBOSE=false
QUIET=false
FORCE_COLOR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            RUN_ALL=true
            shift
            ;;
        --asan)
            RUN_ALL=false
            RUN_ASAN=true
            shift
            ;;
        --ubsan)
            RUN_ALL=false
            RUN_UBSAN=true
            shift
            ;;
        --tsan)
            RUN_ALL=false
            RUN_TSAN=true
            shift
            ;;
        --msan)
            RUN_ALL=false
            RUN_MSAN=true
            shift
            ;;
        --compiler)
            CUSTOM_COMPILER="$2"
            shift 2
            ;;
        --generator)
            GENERATOR="$2"
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
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        --no-report)
            NO_REPORT=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
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

# Set individual sanitizer flags if --all is true
if [[ "$RUN_ALL" == true ]]; then
    RUN_ASAN=true
    RUN_UBSAN=true
    RUN_TSAN=true
    RUN_MSAN=true
fi

# Validate conflicting sanitizers
if [[ "$RUN_ASAN" == true ]] && [[ "$RUN_TSAN" == true ]] && [[ "$RUN_ALL" != true ]]; then
    log_warning "ASan and TSan cannot be used together, running separately"
fi

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    # Print header
    if [[ "$QUIET" != true ]]; then
        log_info "Starting {{ project_name }} sanitizer analysis..."
        echo
    fi
    
    show_config
    
    if [[ "$QUIET" != true ]]; then
        echo
    fi
    
    # Detect available compilers
    local available_compilers
    if ! available_compilers=($(detect_compilers)); then
        log_error "No suitable compilers found"
        exit 1
    fi
    
    log_debug "Available compilers: ${available_compilers[*]}"
    
    local sanitizers_run=()
    local results=()
    
    # Run Address Sanitizer
    if [[ "$RUN_ASAN" == true ]]; then
        local compiler
        if [[ -n "$CUSTOM_COMPILER" ]]; then
            compiler="$CUSTOM_COMPILER"
        elif compiler=$(select_compiler "asan" "${available_compilers[@]}"); then
            log_debug "Selected compiler for ASan: $compiler"
        else
            log_warning "No compiler supports Address Sanitizer, skipping"
            continue
        fi
        
        if build_with_sanitizer "asan" "$compiler"; then
            sanitizers_run+=("asan")
            
            if [[ "$SKIP_TESTS" != true ]]; then
                local test_results
                test_results=$(run_sanitizer_tests "asan")
                echo "$test_results" > "$BUILD_DIR/sanitizer_asan_results.txt"
                results+=("ASan: $test_results")
            fi
        fi
    fi
    
    # Run Undefined Behavior Sanitizer
    if [[ "$RUN_UBSAN" == true ]]; then
        local compiler
        if [[ -n "$CUSTOM_COMPILER" ]]; then
            compiler="$CUSTOM_COMPILER"
        elif compiler=$(select_compiler "ubsan" "${available_compilers[@]}"); then
            log_debug "Selected compiler for UBSan: $compiler"
        else
            log_warning "No compiler supports Undefined Behavior Sanitizer, skipping"
            continue
        fi
        
        if build_with_sanitizer "ubsan" "$compiler"; then
            sanitizers_run+=("ubsan")
            
            if [[ "$SKIP_TESTS" != true ]]; then
                local test_results
                test_results=$(run_sanitizer_tests "ubsan")
                echo "$test_results" > "$BUILD_DIR/sanitizer_ubsan_results.txt"
                results+=("UBSan: $test_results")
            fi
        fi
    fi
    
    # Run Thread Sanitizer
    if [[ "$RUN_TSAN" == true ]]; then
        local compiler
        if [[ -n "$CUSTOM_COMPILER" ]]; then
            compiler="$CUSTOM_COMPILER"
        elif compiler=$(select_compiler "tsan" "${available_compilers[@]}"); then
            log_debug "Selected compiler for TSan: $compiler"
        else
            log_warning "No compiler supports Thread Sanitizer, skipping"
            continue
        fi
        
        if build_with_sanitizer "tsan" "$compiler"; then
            sanitizers_run+=("tsan")
            
            if [[ "$SKIP_TESTS" != true ]]; then
                local test_results
                test_results=$(run_sanitizer_tests "tsan")
                echo "$test_results" > "$BUILD_DIR/sanitizer_tsan_results.txt"
                results+=("TSan: $test_results")
            fi
        fi
    fi
    
    # Run Memory Sanitizer (clang only)
    if [[ "$RUN_MSAN" == true ]]; then
        local compiler
        if [[ -n "$CUSTOM_COMPILER" ]]; then
            if [[ "$CUSTOM_COMPILER" =~ clang ]]; then
                compiler="$CUSTOM_COMPILER"
            else
                log_warning "Memory Sanitizer requires clang++, skipping"
                continue
            fi
        elif compiler=$(select_compiler "msan" "${available_compilers[@]}"); then
            if [[ ! "$compiler" =~ clang ]]; then
                log_warning "Memory Sanitizer requires clang++, skipping"
                continue
            fi
            log_debug "Selected compiler for MSan: $compiler"
        else
            log_warning "No clang compiler supports Memory Sanitizer, skipping"
            continue
        fi
        
        if build_with_sanitizer "msan" "$compiler"; then
            sanitizers_run+=("msan")
            
            if [[ "$SKIP_TESTS" != true ]]; then
                local test_results
                test_results=$(run_sanitizer_tests "msan")
                echo "$test_results" > "$BUILD_DIR/sanitizer_msan_results.txt"
                results+=("MSan: $test_results")
            fi
        fi
    fi
    
    # Generate report
    if [[ ${#sanitizers_run[@]} -gt 0 ]]; then
        generate_report "${sanitizers_run[@]}"
    fi
    
    # Final summary
    if [[ "$QUIET" != true ]]; then
        echo
        if [[ "$DRY_RUN" == true ]]; then
            log_success "Dry run completed - no sanitizers were actually run"
        else
            if [[ ${#sanitizers_run[@]} -gt 0 ]]; then
                log_success "{{ project_name }} sanitizer analysis completed!"
                log_info "Sanitizers run: ${sanitizers_run[*]}"
                
                if [[ "$SKIP_TESTS" != true ]] && [[ ${#results[@]} -gt 0 ]]; then
                    echo
                    log_info "Test Results Summary:"
                    for result in "${results[@]}"; do
                        echo "  $result"
                    done
                fi
            else
                log_warning "No sanitizers were run"
            fi
        fi
    fi
}

# Run main function
main "$@" 