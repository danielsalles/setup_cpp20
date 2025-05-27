#!/bin/bash

# 🛡️ Strict error handling
set -euo pipefail

# 🎨 Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

BUILD_TYPE="Release"
COMPILER="clang++"
CLEAN=false
RUN_AFTER=false
VERBOSE=false
USE_VCPKG=false
USE_CONAN=false
JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "4")

# 📋 Show help
show_help() {
    echo -e "${CYAN}🚀 Modern C++20 Build Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE     Build type (Debug, Release, RelWithDebInfo) [default: Release]"
    echo "  -c, --compiler COMP Compiler (clang++, g++) [default: clang++]"
    echo "  --clean            Clean build directory first"
    echo "  -r, --run          Run the executable after building"
    echo "  -v, --verbose      Verbose build output"
    echo "  --vcpkg            Use vcpkg for dependencies"
    echo "  --conan            Use Conan for dependencies"
    echo "  -j, --jobs N       Number of parallel jobs [default: auto-detected]"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Quick release build"
    echo "  $0 -t Debug -r              # Debug build and run"
    echo "  $0 --clean -c g++ --vcpkg   # Clean build with GCC and vcpkg"
    echo "  $0 --conan -j 8             # Build with Conan using 8 jobs"
}

# 📊 Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -c|--compiler)
            COMPILER="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        -r|--run)
            RUN_AFTER=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --vcpkg)
            USE_VCPKG=true
            shift
            ;;
        --conan)
            USE_CONAN=true
            shift
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 🔍 Validate build type
case $BUILD_TYPE in
    Debug|Release|RelWithDebInfo)
        ;;
    *)
        echo -e "${RED}❌ Invalid build type: $BUILD_TYPE${NC}"
        echo -e "${YELLOW}Valid types: Debug, Release, RelWithDebInfo${NC}"
        exit 1
        ;;
esac

# 🔍 Check if compiler exists
if ! command -v "$COMPILER" &> /dev/null; then
    echo -e "${RED}❌ Compiler '$COMPILER' not found!${NC}"
    echo -e "${YELLOW}💡 Make sure you've run the setup script first${NC}"
    exit 1
fi

# 🔍 Check if CMake exists
if ! command -v cmake &> /dev/null; then
    echo -e "${RED}❌ CMake not found!${NC}"
    echo -e "${YELLOW}💡 Make sure you've run the setup script first${NC}"
    exit 1
fi

# 🔍 Check if Ninja exists
if ! command -v ninja &> /dev/null; then
    echo -e "${RED}❌ Ninja not found!${NC}"
    echo -e "${YELLOW}💡 Make sure you've run the setup script first${NC}"
    exit 1
fi

# 🎯 Header
echo -e "${PURPLE}╔════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}          ${CYAN}🚀 C++20 Modern Build${NC}          ${PURPLE}║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════╝${NC}"
echo ""

# 📊 Show build configuration
echo -e "${BLUE}📋 Build Configuration:${NC}"
echo -e "  🔧 Compiler: ${GREEN}$COMPILER${NC} ($(${COMPILER} --version | head -n1))"
echo -e "  📁 Build Type: ${GREEN}$BUILD_TYPE${NC}"
echo -e "  🧹 Clean Build: ${GREEN}$CLEAN${NC}"
echo -e "  🏃 Run After: ${GREEN}$RUN_AFTER${NC}"
echo -e "  🔊 Verbose: ${GREEN}$VERBOSE${NC}"
echo -e "  📦 vcpkg: ${GREEN}$USE_VCPKG${NC}"
echo -e "  🐍 Conan: ${GREEN}$USE_CONAN${NC}"
echo -e "  ⚡ Jobs: ${GREEN}$JOBS${NC}"
echo ""

# 🧹 Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}🧹 Cleaning build directory...${NC}"
    rm -rf build
fi

# 📁 Create build directory
mkdir -p build

# 🐍 Handle Conan dependencies
if [ "$USE_CONAN" = true ]; then
    echo -e "${BLUE}🐍 Setting up Conan dependencies...${NC}"
    if ! command -v conan &> /dev/null; then
        echo -e "${RED}❌ Conan not found!${NC}"
        echo -e "${YELLOW}💡 Make sure you've run the setup script first${NC}"
        exit 1
    fi
    
    if [ -f "conanfile.txt" ] || [ -f "conanfile.py" ]; then
        conan install . --output-folder=build --build=missing
    else
        echo -e "${YELLOW}⚠️  No conanfile.txt or conanfile.py found${NC}"
    fi
fi

# 🏗️ Configure with CMake
echo -e "${BLUE}⚙️  Configuring project...${NC}"
cd build

CMAKE_ARGS=(
    ".."
    "-DCMAKE_BUILD_TYPE=$BUILD_TYPE"
    "-DCMAKE_CXX_COMPILER=$COMPILER"
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
    "-G" "Ninja"
)

# 📦 Add vcpkg toolchain if requested
if [ "$USE_VCPKG" = true ]; then
    VCPKG_ROOT="$HOME/vcpkg"
    if [ -d "$VCPKG_ROOT" ]; then
        CMAKE_ARGS+=("-DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake")
        echo -e "${GREEN}📦 Using vcpkg toolchain${NC}"
    else
        echo -e "${YELLOW}⚠️  vcpkg not found at $VCPKG_ROOT${NC}"
    fi
fi

# 🐍 Add Conan toolchain if available
if [ "$USE_CONAN" = true ] && [ -f "conan_toolchain.cmake" ]; then
    CMAKE_ARGS+=("-DCMAKE_TOOLCHAIN_FILE=conan_toolchain.cmake")
    echo -e "${GREEN}🐍 Using Conan toolchain${NC}"
fi

cmake "${CMAKE_ARGS[@]}"

# 🔨 Build
echo -e "${BLUE}🔨 Building project...${NC}"
NINJA_ARGS=("-j" "$JOBS")

if [ "$VERBOSE" = true ]; then
    NINJA_ARGS+=("-v")
fi

ninja "${NINJA_ARGS[@]}"

# ✅ Success message
echo ""
echo -e "${GREEN}✅ Build completed successfully!${NC}"

# 📊 Show binary info
BINARY="./ModernCpp20Demo"
if [ -f "$BINARY" ]; then
    echo -e "${BLUE}📊 Binary information:${NC}"
    echo -e "  📄 Size: ${GREEN}$(du -h "$BINARY" | cut -f1)${NC}"
    echo -e "  🏗️  Type: ${GREEN}$(file "$BINARY" | cut -d: -f2)${NC}"
    
    # 🔍 Show dependencies (macOS)
    if command -v otool &> /dev/null; then
        echo -e "  🔗 Dependencies: ${GREEN}$(otool -L "$BINARY" | wc -l | tr -d ' ')${NC} libraries"
    fi
fi

# 🏃 Run if requested
if [ "$RUN_AFTER" = true ] && [ -f "$BINARY" ]; then
    echo ""
    echo -e "${PURPLE}🏃 Running executable...${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${NC}"
    "$BINARY"
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${NC}"
fi

echo ""
echo -e "${GREEN}🎉 All done! Happy coding!${NC}"