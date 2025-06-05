#!/bin/bash

# {{ project_name }} Build Script
# Modern C++20 project build automation with enhanced features

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
readonly ARCH_TYPE="$(uname -m)"

# Logging functions with emojis
log_info() {
    echo -e "${BLUE}ℹ️  [INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}✅ [SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠️  [WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}❌ [ERROR]${NC} $*"
}

log_debug() {
    if [[ "${VERBOSE:-false}" == true ]]; then
        echo -e "${PURPLE}🔍 [DEBUG]${NC} $*"
    fi
}

# Detect available compilers
detect_compilers() {
    local compilers=()
    
    command -v gcc >/dev/null 2>&1 && compilers+=("gcc")
    command -v clang >/dev/null 2>&1 && compilers+=("clang")
    command -v g++ >/dev/null 2>&1 && compilers+=("g++")
    command -v clang++ >/dev/null 2>&1 && compilers+=("clang++")
    
    if [[ "$OS_TYPE" == "Windows_NT" ]] || [[ "$OS_TYPE" =~ MINGW|MSYS|CYGWIN ]]; then
        command -v cl.exe >/dev/null 2>&1 && compilers+=("msvc")
    fi
    
    printf '%s\n' "${compilers[@]}"
}

# Detect build tools and generators
detect_build_tools() {
    local generators=()
    
    if command -v ninja >/dev/null 2>&1; then
        generators+=("Ninja")
    fi
    
    if command -v make >/dev/null 2>&1; then
        generators+=("Unix Makefiles")
    fi
    
    if [[ "$OS_TYPE" == "Windows_NT" ]] || [[ "$OS_TYPE" =~ MINGW|MSYS|CYGWIN ]]; then
        if command -v MSBuild.exe >/dev/null 2>&1; then
            generators+=("Visual Studio")
        fi
    fi
    
    printf '%s\n' "${generators[@]}"
}

# Platform-specific job count detection
detect_cpu_count() {
    case "$OS_TYPE" in
        Linux*)
            nproc 2>/dev/null || echo "4"
            ;;
        Darwin*)
            sysctl -n hw.ncpu 2>/dev/null || echo "4"
            ;;
        Windows_NT|MINGW*|MSYS*|CYGWIN*)
            echo "${NUMBER_OF_PROCESSORS:-4}"
            ;;
        *)
            echo "4"
            ;;
    esac
}

# Check for ccache availability
setup_ccache() {
    if command -v ccache >/dev/null 2>&1; then
        export CC="ccache ${CC:-gcc}"
        export CXX="ccache ${CXX:-g++}"
        log_info "Using ccache for faster builds"
        return 0
    fi
    return 1
}

# Print usage information
print_usage() {
    cat << EOF
${BOLD}{{ project_name }} Build Script${NC}
Modern C++20 project build automation with enhanced features

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}BUILD OPTIONS:${NC}
    -t, --type TYPE         Build type: Debug, Release, RelWithDebInfo, MinSizeRel (default: Release)
    -g, --generator GEN     CMake generator: Ninja, "Unix Makefiles", etc. (default: auto-detect)
    -c, --clean             Clean build directory before building
    -j, --jobs JOBS         Number of parallel jobs (default: auto-detect)
    --compiler COMPILER     Compiler: gcc, clang, g++, clang++, msvc (default: auto-detect)
    --ccache                Enable ccache if available
    --no-ccache             Disable ccache

${BOLD}FEATURE OPTIONS:${NC}
    -s, --sanitizers        Enable sanitizers (Debug builds only)
    -a, --static-analysis   Enable static analysis tools
    -T, --tests             Build and run tests
    -e, --examples          Build examples
    --coverage              Enable code coverage (Debug builds only)

${BOLD}OUTPUT OPTIONS:${NC}
    -v, --verbose           Enable verbose output
    -q, --quiet             Suppress non-essential output
    --color                 Force colored output
    --no-color              Disable colored output

${BOLD}INSTALL OPTIONS:${NC}
    -i, --install           Install after successful build
    --install-prefix PATH   Installation prefix (default: /usr/local)

${BOLD}CUSTOM OPTIONS:${NC}
    --cmake-args "ARGS"     Additional CMake arguments
    --cxx-flags "FLAGS"     Additional C++ compiler flags
    --env-file FILE         Source environment variables from file

${BOLD}UTILITY OPTIONS:${NC}
    --retry N               Retry build N times on failure (default: 0)
    --list-compilers        List available compilers and exit
    --list-generators       List available generators and exit
    -h, --help              Show this help message

${BOLD}EXAMPLES:${NC}
    $0                                    # Build Release version
    $0 -t Debug -s -T --ccache           # Debug build with sanitizers, tests, and ccache
    $0 -c -t Release -j 8 -i             # Clean Release build with 8 jobs and install
    $0 --compiler clang --static-analysis # Build with Clang and static analysis
    $0 --cmake-args "-DFOO=bar" --cxx-flags "-march=native"  # Custom build flags

${BOLD}ENVIRONMENT VARIABLES:${NC}
    CC                      C compiler
    CXX                     C++ compiler  
    CXXFLAGS               C++ compiler flags
    CMAKE_ARGS             Additional CMake arguments
    VCPKG_ROOT             vcpkg installation directory

EOF
}

# Default values
BUILD_TYPE="Release"
GENERATOR=""
CLEAN_BUILD=false
JOBS=$(detect_cpu_count)
VERBOSE=false
QUIET=false
ENABLE_SANITIZERS=false
ENABLE_STATIC_ANALYSIS=false
ENABLE_COVERAGE=false
BUILD_TESTS=false
BUILD_EXAMPLES=false
INSTALL_AFTER_BUILD=false
INSTALL_PREFIX="/usr/local"
COMPILER=""
USE_CCACHE=""
CUSTOM_CMAKE_ARGS=""
CUSTOM_CXX_FLAGS=""
ENV_FILE=""
RETRY_COUNT=0
FORCE_COLOR=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -g|--generator)
            GENERATOR="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        --compiler)
            COMPILER="$2"
            shift 2
            ;;
        --ccache)
            USE_CCACHE=true
            shift
            ;;
        --no-ccache)
            USE_CCACHE=false
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
        -s|--sanitizers)
            ENABLE_SANITIZERS=true
            shift
            ;;
        -a|--static-analysis)
            ENABLE_STATIC_ANALYSIS=true
            shift
            ;;
        --coverage)
            ENABLE_COVERAGE=true
            shift
            ;;
        -T|--tests)
            BUILD_TESTS=true
            shift
            ;;
        -e|--examples)
            BUILD_EXAMPLES=true
            shift
            ;;
        -i|--install)
            INSTALL_AFTER_BUILD=true
            shift
            ;;
        --install-prefix)
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --cmake-args)
            CUSTOM_CMAKE_ARGS="$2"
            shift 2
            ;;
        --cxx-flags)
            CUSTOM_CXX_FLAGS="$2"
            shift 2
            ;;
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --retry)
            RETRY_COUNT="$2"
            shift 2
            ;;
        --list-compilers)
            echo "Available compilers:"
            detect_compilers | sed 's/^/  /'
            exit 0
            ;;
        --list-generators)
            echo "Available generators:"
            detect_build_tools | sed 's/^/  /'
            exit 0
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

# Load environment file if specified
if [[ -n "$ENV_FILE" ]] && [[ -f "$ENV_FILE" ]]; then
    log_info "Loading environment from: $ENV_FILE"
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

# Validate build type
case "$BUILD_TYPE" in
    Debug|Release|RelWithDebInfo|MinSizeRel)
        ;;
    *)
        log_error "Invalid build type: $BUILD_TYPE"
        log_info "Valid types: Debug, Release, RelWithDebInfo, MinSizeRel"
        exit 1
        ;;
esac

# Auto-detect generator if not specified
if [[ -z "$GENERATOR" ]]; then
    available_generators=($(detect_build_tools))
    if [[ ${#available_generators[@]} -gt 0 ]]; then
        GENERATOR="${available_generators[0]}"
        log_debug "Auto-selected generator: $GENERATOR"
    else
        log_error "No suitable build generator found"
        exit 1
    fi
fi

# Compiler selection
if [[ -n "$COMPILER" ]]; then
    case "$COMPILER" in
        gcc)
            export CC=gcc CXX=g++
            ;;
        clang)
            export CC=clang CXX=clang++
            ;;
        g++)
            export CC=gcc CXX=g++
            ;;
        clang++)
            export CC=clang CXX=clang++
            ;;
        msvc)
            # Will be handled by CMake on Windows
            ;;
        *)
            log_error "Unknown compiler: $COMPILER"
            log_info "Available compilers:"
            detect_compilers | sed 's/^/  /'
            exit 1
            ;;
    esac
    log_info "Using compiler: $COMPILER"
fi

# Setup ccache if requested or auto-detect
if [[ "$USE_CCACHE" == true ]] || [[ -z "$USE_CCACHE" && "$USE_CCACHE" != false ]]; then
    setup_ccache || true
fi

# Check for required tools
check_requirements() {
    local missing_tools=()
    
    command -v cmake >/dev/null 2>&1 || missing_tools+=("cmake")
    
    # Check for generator-specific tools
    case "$GENERATOR" in
        "Ninja")
            command -v ninja >/dev/null 2>&1 || missing_tools+=("ninja")
            ;;
        "Unix Makefiles")
            command -v make >/dev/null 2>&1 || missing_tools+=("make")
            ;;
    esac
    
    if [[ ${#missing_tools[@]} -ne 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again"
        exit 1
    fi
}

# Setup build environment
setup_environment() {
    log_info "Setting up build environment..."
    
    # Export vcpkg root if available
    local vcpkg_paths=("$HOME/.vcpkg" "/opt/vcpkg" "${VCPKG_ROOT:-}")
    for vcpkg_path in "${vcpkg_paths[@]}"; do
        if [[ -d "$vcpkg_path" ]]; then
            export VCPKG_ROOT="$vcpkg_path"
            log_info "Using vcpkg at: $VCPKG_ROOT"
            break
        fi
    done
    
    # Create build directory
    if [[ "$CLEAN_BUILD" == true ]] && [[ -d "$BUILD_DIR" ]]; then
        log_info "Cleaning build directory..."
        rm -rf "$BUILD_DIR"
    fi
    
    mkdir -p "$BUILD_DIR"
    
    # Apply custom environment variables
    if [[ -n "$CUSTOM_CXX_FLAGS" ]]; then
        export CXXFLAGS="${CXXFLAGS:-} $CUSTOM_CXX_FLAGS"
        log_info "Custom CXXFLAGS: $CUSTOM_CXX_FLAGS"
    fi
}

# Configure the project with retry mechanism
configure_project() {
    local attempt=1
    local max_attempts=$((RETRY_COUNT + 1))
    
    while [[ $attempt -le $max_attempts ]]; do
        if [[ $attempt -gt 1 ]]; then
            log_warning "Configuration attempt $attempt of $max_attempts..."
            sleep 2
        fi
        
        log_info "Configuring {{ project_name }} ($BUILD_TYPE) with $GENERATOR..."
        
        cd "$BUILD_DIR"
        
        local cmake_args=(
            -G "$GENERATOR"
            -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
            -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
            -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"
        )
        
        # Add vcpkg toolchain if available
        if [[ -n "${VCPKG_ROOT:-}" ]] && [[ -f "$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" ]]; then
            cmake_args+=(-DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake")
        fi
        
        # Build options
        [[ "$BUILD_TESTS" == true ]] && cmake_args+=(-DBUILD_TESTS=ON)
        [[ "$BUILD_EXAMPLES" == true ]] && cmake_args+=(-DBUILD_EXAMPLE=ON)
        
        # Coverage (Debug builds only)
        if [[ "$ENABLE_COVERAGE" == true ]] && [[ "$BUILD_TYPE" == "Debug" ]]; then
            cmake_args+=(
                -DENABLE_COVERAGE=ON
                -DCMAKE_CXX_FLAGS="--coverage"
                -DCMAKE_EXE_LINKER_FLAGS="--coverage"
            )
            log_info "Code coverage enabled for Debug build"
        elif [[ "$ENABLE_COVERAGE" == true ]]; then
            log_warning "Code coverage only available for Debug builds"
        fi
        
        # Sanitizers (Debug builds only)
        if [[ "$ENABLE_SANITIZERS" == true ]] && [[ "$BUILD_TYPE" == "Debug" ]]; then
            cmake_args+=(
                -DENABLE_SANITIZER_ADDRESS=ON
                -DENABLE_SANITIZER_LEAK=ON
                -DENABLE_SANITIZER_UNDEFINED_BEHAVIOR=ON
            )
            log_info "Sanitizers enabled for Debug build"
        elif [[ "$ENABLE_SANITIZERS" == true ]]; then
            log_warning "Sanitizers only available for Debug builds"
        fi
        
        # Static analysis
        if [[ "$ENABLE_STATIC_ANALYSIS" == true ]]; then
            cmake_args+=(
                -DENABLE_CLANG_TIDY=ON
                -DENABLE_CPPCHECK=ON
            )
            log_info "Static analysis tools enabled"
        fi
        
        # Verbose output
        if [[ "$VERBOSE" == true ]]; then
            cmake_args+=(-DCMAKE_VERBOSE_MAKEFILE=ON)
        fi
        
        # Add custom cmake arguments
        if [[ -n "$CUSTOM_CMAKE_ARGS" ]]; then
            # Parse custom args properly
            eval "cmake_args+=($CUSTOM_CMAKE_ARGS)"
            log_info "Custom CMake args: $CUSTOM_CMAKE_ARGS"
        fi
        
        # Add environment-based cmake args
        if [[ -n "${CMAKE_ARGS:-}" ]]; then
            eval "cmake_args+=(${CMAKE_ARGS})"
            log_info "Environment CMake args: $CMAKE_ARGS"
        fi
        
        # Run CMake configuration
        if [[ "$QUIET" == false ]]; then
            log_debug "CMake command: cmake ${cmake_args[*]} $PROJECT_ROOT"
        fi
        
        if cmake "${cmake_args[@]}" "$PROJECT_ROOT"; then
            log_success "Configuration completed successfully"
            return 0
        else
            log_error "Configuration failed (attempt $attempt)"
            ((attempt++))
        fi
    done
    
    log_error "Configuration failed after $max_attempts attempts"
    exit 1
}

# Build the project with retry mechanism
build_project() {
    local attempt=1
    local max_attempts=$((RETRY_COUNT + 1))
    
    while [[ $attempt -le $max_attempts ]]; do
        if [[ $attempt -gt 1 ]]; then
            log_warning "Build attempt $attempt of $max_attempts..."
            sleep 2
        fi
        
        log_info "Building {{ project_name }} with $JOBS parallel jobs..."
        
        cd "$BUILD_DIR"
        
        declare -a build_args=()
        
        case "$GENERATOR" in
            "Ninja")
                build_args=(ninja -j "$JOBS")
                [[ "$VERBOSE" == true ]] && build_args+=(-v)
                ;;
            "Unix Makefiles")
                build_args=(make -j "$JOBS")
                [[ "$VERBOSE" == true ]] && build_args+=(VERBOSE=1)
                ;;
            *)
                build_args=(cmake --build . --config "$BUILD_TYPE" --parallel "$JOBS")
                [[ "$VERBOSE" == true ]] && build_args+=(--verbose)
                ;;
        esac
        
        if [[ "$QUIET" == false ]]; then
            log_debug "Build command: ${build_args[*]}"
        fi
        
        if "${build_args[@]}"; then
            log_success "Build completed successfully"
            return 0
        else
            log_error "Build failed (attempt $attempt)"
            ((attempt++))
        fi
    done
    
    log_error "Build failed after $max_attempts attempts"
    exit 1
}

# Run tests if requested
run_tests() {
    if [[ "$BUILD_TESTS" == true ]]; then
        log_info "Running tests..."
        
        cd "$BUILD_DIR"
        
        declare -a test_args=(ctest --output-on-failure -j "$JOBS")
        [[ "$VERBOSE" == true ]] && test_args+=(--verbose)
        [[ "$QUIET" == true ]] && test_args+=(--quiet)
        
        if "${test_args[@]}"; then
            log_success "All tests passed"
            
            # Generate coverage report if enabled
            if [[ "$ENABLE_COVERAGE" == true ]] && [[ "$BUILD_TYPE" == "Debug" ]]; then
                generate_coverage_report
            fi
        else
            log_error "Some tests failed"
            exit 1
        fi
    fi
}

# Generate coverage report
generate_coverage_report() {
    log_info "Generating coverage report..."
    
    if command -v lcov >/dev/null 2>&1; then
        # Generate lcov report
        lcov --capture --directory . --output-file coverage.info
        lcov --remove coverage.info '/usr/*' --output-file coverage.info
        lcov --remove coverage.info '*_test.cpp' --output-file coverage.info
        
        if command -v genhtml >/dev/null 2>&1; then
            genhtml coverage.info --output-directory coverage_html
            log_success "Coverage report generated: $BUILD_DIR/coverage_html/index.html"
        fi
    elif command -v gcovr >/dev/null 2>&1; then
        # Generate gcovr report
        gcovr --html --html-details -o coverage.html .
        log_success "Coverage report generated: $BUILD_DIR/coverage.html"
    else
        log_warning "No coverage tool found (lcov or gcovr required)"
    fi
}

# Install if requested
install_project() {
    if [[ "$INSTALL_AFTER_BUILD" == true ]]; then
        log_info "Installing {{ project_name }} to $INSTALL_PREFIX..."
        
        cd "$BUILD_DIR"
        
        declare -a install_args=()
        
        case "$GENERATOR" in
            "Ninja")
                install_args=(ninja install)
                ;;
            "Unix Makefiles")
                install_args=(make install)
                ;;
            *)
                install_args=(cmake --build . --target install)
                ;;
        esac
        
        if "${install_args[@]}"; then
            log_success "Installation completed successfully"
        else
            log_error "Installation failed"
            exit 1
        fi
    fi
}

# Print build summary
print_summary() {
    if [[ "$QUIET" == true ]]; then
        return
    fi
    
    log_info "Build Summary:"
    echo "  Project: {{ project_name }}"
    echo "  Build Type: $BUILD_TYPE"
    echo "  Generator: $GENERATOR"
    echo "  Compiler: ${COMPILER:-auto-detect}"
    echo "  Build Directory: $BUILD_DIR"
    echo "  Parallel Jobs: $JOBS"
    echo "  Platform: $OS_TYPE ($ARCH_TYPE)"
    
    if [[ -n "${CC:-}" ]] && [[ -n "${CXX:-}" ]]; then
        echo "  C Compiler: $CC"
        echo "  C++ Compiler: $CXX"
    fi
    
    echo "  Tests: $([ "$BUILD_TESTS" == true ] && echo "Enabled" || echo "Disabled")"
    echo "  Examples: $([ "$BUILD_EXAMPLES" == true ] && echo "Enabled" || echo "Disabled")"
    echo "  Coverage: $([ "$ENABLE_COVERAGE" == true ] && [ "$BUILD_TYPE" == "Debug" ] && echo "Enabled" || echo "Disabled")"
    echo "  Sanitizers: $([ "$ENABLE_SANITIZERS" == true ] && [ "$BUILD_TYPE" == "Debug" ] && echo "Enabled" || echo "Disabled")"
    echo "  Static Analysis: $([ "$ENABLE_STATIC_ANALYSIS" == true ] && echo "Enabled" || echo "Disabled")"
    echo "  ccache: $([ -n "${CC:-}" ] && [[ "$CC" =~ ccache ]] && echo "Enabled" || echo "Disabled")"
    echo "  Install: $([ "$INSTALL_AFTER_BUILD" == true ] && echo "Yes ($INSTALL_PREFIX)" || echo "No")"
    
    if [[ -n "$CUSTOM_CMAKE_ARGS" ]]; then
        echo "  Custom CMake Args: $CUSTOM_CMAKE_ARGS"
    fi
    
    if [[ -n "$CUSTOM_CXX_FLAGS" ]]; then
        echo "  Custom CXX Flags: $CUSTOM_CXX_FLAGS"
    fi
}

# Show build artifacts
show_artifacts() {
    if [[ "$QUIET" == true ]]; then
        return
    fi
    
    log_info "Build artifacts:"
    
    # Show executable
    if [[ -f "$BUILD_DIR/bin/{{ project_name }}" ]]; then
        echo "  Executable: $BUILD_DIR/bin/{{ project_name }}"
    elif [[ -f "$BUILD_DIR/bin/{{ project_name }}.exe" ]]; then
        echo "  Executable: $BUILD_DIR/bin/{{ project_name }}.exe"
    fi
    
    # Show library
    if [[ -f "$BUILD_DIR/lib/lib{{ project_name }}.a" ]]; then
        echo "  Static Library: $BUILD_DIR/lib/lib{{ project_name }}.a"
    elif [[ -f "$BUILD_DIR/lib/lib{{ project_name }}.so" ]]; then
        echo "  Shared Library: $BUILD_DIR/lib/lib{{ project_name }}.so"
    elif [[ -f "$BUILD_DIR/lib/{{ project_name }}.lib" ]]; then
        echo "  Library: $BUILD_DIR/lib/{{ project_name }}.lib"
    fi
    
    # Show compile commands database
    if [[ -f "$BUILD_DIR/compile_commands.json" ]]; then
        echo "  Compile Commands: $BUILD_DIR/compile_commands.json"
    fi
    
    # Show coverage report
    if [[ -f "$BUILD_DIR/coverage.html" ]]; then
        echo "  Coverage Report: $BUILD_DIR/coverage.html"
    elif [[ -d "$BUILD_DIR/coverage_html" ]]; then
        echo "  Coverage Report: $BUILD_DIR/coverage_html/index.html"
    fi
}

# Cleanup function for error handling
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]] && [[ "$QUIET" == false ]]; then
        log_error "Build process failed with exit code $exit_code"
        
        # Show helpful debugging information
        if [[ -d "$BUILD_DIR" ]]; then
            log_info "Build directory: $BUILD_DIR"
            if [[ -f "$BUILD_DIR/CMakeCache.txt" ]]; then
                log_info "CMake cache exists, you can inspect it for configuration issues"
            fi
        fi
        
        log_info "Run with --verbose for more detailed output"
        log_info "Run with --help to see all available options"
    fi
    exit $exit_code
}

# Set up signal trapping for cleanup
trap cleanup EXIT

# Main execution
main() {
    # Print header
    if [[ "$QUIET" == false ]]; then
        log_info "Starting {{ project_name }} build process..."
        echo
    fi
    
    print_summary
    
    if [[ "$QUIET" == false ]]; then
        echo
    fi
    
    check_requirements
    setup_environment
    configure_project
    build_project
    run_tests
    install_project
    
    if [[ "$QUIET" == false ]]; then
        echo
        log_success "{{ project_name }} build process completed!"
        echo
        show_artifacts
    fi
}

# Run main function
main "$@" 