#!/bin/bash

# 🏗️ C++20 PROJECT GENERATOR
# Creates production-ready C++20 projects with modern tooling
# Usage: curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/helpers/create-cpp20-project.sh | bash -s project-name

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
PROJECT_TYPE="${2:-console}"  # console, library, gui
USE_VCPKG="${3:-true}"
USE_TESTING="${4:-true}"

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}" >&2; }
log_header() { echo -e "${PURPLE}🚀 $*${NC}"; }

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║            🏗️ C++20 PROJECT GENERATOR                      ║
║                                                            ║
║  Creates modern C++20 projects with:                       ║
║  • CMake configuration                                     ║
║  • vcpkg integration                                       ║
║  • Testing framework                                       ║
║  • CI/CD workflows                                         ║
║  • Modern C++20 examples                                   ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

get_project_info() {
    if [[ -z "$PROJECT_NAME" ]]; then
        echo -e "${CYAN}Enter project details:${NC}"
        read -p "Project name: " PROJECT_NAME
        
        echo "Project types:"
        echo "  1) console - Console application (default)"
        echo "  2) library - Static/shared library"
        echo "  3) gui - GUI application"
        read -p "Project type (1-3): " choice
        
        case $choice in
            2) PROJECT_TYPE="library" ;;
            3) PROJECT_TYPE="gui" ;;
            *) PROJECT_TYPE="console" ;;
        esac
        
        read -p "Use vcpkg? (Y/n): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Nn]$ ]] && USE_VCPKG="false" || USE_VCPKG="true"
        
        read -p "Include testing? (Y/n): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Nn]$ ]] && USE_TESTING="false" || USE_TESTING="true"
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
    
    mkdir -p "$PROJECT_NAME"/{src,include/"$PROJECT_NAME",tests,docs,scripts,.github/workflows}
    cd "$PROJECT_NAME"
    
    log_success "Directory structure created"
}

create_cmake_files() {
    log_header "Creating CMake Configuration"
    
    # Main CMakeLists.txt
    cat > CMakeLists.txt << CMAKE_EOF
cmake_minimum_required(VERSION 3.25)

# 🎯 Project definition
project(${PROJECT_NAME}
    VERSION 1.0.0
    DESCRIPTION "Modern C++20 ${PROJECT_TYPE} project"
    LANGUAGES CXX
)

# 🚀 C++20 is mandatory
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 🔧 Compiler configurations
include(cmake/CompilerWarnings.cmake)
include(cmake/StaticAnalysis.cmake)

# 📦 Package manager integration
include(cmake/VcpkgHelpers.cmake)
vcpkg_find_packages()

# 🎯 Build options
option(BUILD_SHARED_LIBS "Build shared libraries" OFF)
option(ENABLE_TESTING "Enable testing" ${USE_TESTING})
option(ENABLE_BENCHMARKS "Enable benchmarks" OFF)

# 📚 Find packages
# Note: vcpkg_find_packages() above should have found these automatically
# These are fallback manual find_package calls
find_package(fmt CONFIG QUIET)
find_package(spdlog CONFIG QUIET)

# Check if packages were found
if(NOT fmt_FOUND)
    message(WARNING "fmt package not found - install with: vcpkg install fmt")
endif()
if(NOT spdlog_FOUND)
    message(WARNING "spdlog package not found - install with: vcpkg install spdlog")
endif()

CMAKE_EOF

    if [[ "$PROJECT_TYPE" == "console" ]]; then
        cat >> CMakeLists.txt << CMAKE_CONSOLE_EOF

# 🎯 Console application
add_executable(\${PROJECT_NAME})

target_sources(\${PROJECT_NAME} PRIVATE
    src/main.cpp
)

target_include_directories(\${PROJECT_NAME} PRIVATE
    include
)

vcpkg_link_libraries(\${PROJECT_NAME} PRIVATE)

apply_compiler_warnings(\${PROJECT_NAME})

CMAKE_CONSOLE_EOF
    elif [[ "$PROJECT_TYPE" == "library" ]]; then
        cat >> CMakeLists.txt << CMAKE_LIB_EOF

# 📚 Library target
add_library(\${PROJECT_NAME})

target_sources(\${PROJECT_NAME} PRIVATE
    src/${PROJECT_NAME}.cpp
)

target_include_directories(\${PROJECT_NAME} 
    PUBLIC
        \$<BUILD_INTERFACE:\${CMAKE_CURRENT_SOURCE_DIR}/include>
        \$<INSTALL_INTERFACE:include>
    PRIVATE
        src
)

vcpkg_link_libraries(\${PROJECT_NAME} PUBLIC)

apply_compiler_warnings(\${PROJECT_NAME})

# 🎯 Example executable
add_executable(\${PROJECT_NAME}_example
    examples/example.cpp
)

target_link_libraries(\${PROJECT_NAME}_example PRIVATE \${PROJECT_NAME})

CMAKE_LIB_EOF
    fi
    
    if [[ "$USE_TESTING" == "true" ]]; then
        cat >> CMakeLists.txt << CMAKE_TEST_EOF

# 🧪 Testing
if(ENABLE_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()

CMAKE_TEST_EOF
    fi
    
    # Create cmake modules
    mkdir -p cmake
    
    # Compiler warnings
    cat > cmake/CompilerWarnings.cmake << 'WARNING_EOF'
function(apply_compiler_warnings target)
    set(MSVC_WARNINGS
        /W4 /WX /permissive-
        /w14640 # Enable warning on thread un-safe static member initialization
        /w14242 # 'identifier': conversion from 'type1' to 'type1', possible loss of data
        /w14254 # 'operator': conversion from 'type1:field_bits' to 'type2:field_bits', possible loss of data
        /w14263 # 'function': member function does not override any base class virtual member function
        /w14265 # 'classname': class has virtual functions, but destructor is not virtual
        /w14287 # 'operator': unsigned/negative constant mismatch
        /we4289 # nonstandard extension used: 'variable': loop control variable declared in the for-loop is used outside the for-loop scope
        /w14296 # 'operator': expression is always 'boolean_value'
        /w14311 # 'variable': pointer truncation from 'type1' to 'type2'
        /w14545 # expression before comma evaluates to a function which is missing an argument list
        /w14546 # function call before comma missing argument list
        /w14547 # 'operator': operator before comma has no effect; expected operator with side-effect
        /w14549 # 'operator': operator before comma has no effect; did you intend 'operator'?
        /w14555 # expression has no effect; expected expression with side-effect
        /w14619 # pragma warning: there is no warning number 'number'
        /w14640 # Enable warning on thread un-safe static member initialization
        /w14826 # Conversion from 'type1' to 'type_2' is sign-extended. This may cause unexpected runtime behavior.
        /w14905 # wide string literal cast to 'LPSTR'
        /w14906 # string literal cast to 'LPWSTR'
        /w14928 # illegal copy-initialization; more than one user-defined conversion has been implicitly applied
    )

    set(CLANG_WARNINGS
        -Wall -Wextra -Wpedantic
        -Wunused -Wformat=2
        -Wnull-dereference
        -Wdouble-promotion
        -Wshadow
        -Wconversion
        -Wsign-conversion
        -Wno-unused-parameter
    )

    set(GCC_WARNINGS
        ${CLANG_WARNINGS}
        -Wduplicated-cond
        -Wduplicated-branches
        -Wlogical-op
        -Wuseless-cast
    )

    if(MSVC)
        target_compile_options(${target} PRIVATE ${MSVC_WARNINGS})
    elseif(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
        target_compile_options(${target} PRIVATE ${CLANG_WARNINGS})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        target_compile_options(${target} PRIVATE ${GCC_WARNINGS})
    endif()
endfunction()
WARNING_EOF
    
    # Static analysis
    cat > cmake/StaticAnalysis.cmake << 'ANALYSIS_EOF'
option(ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
option(ENABLE_CPPCHECK "Enable cppcheck" OFF)

if(ENABLE_CLANG_TIDY)
    find_program(CLANGTIDY clang-tidy)
    if(CLANGTIDY)
        set(CMAKE_CXX_CLANG_TIDY ${CLANGTIDY})
        message(STATUS "🔍 clang-tidy enabled")
    else()
        message(SEND_ERROR "🔍 clang-tidy requested but not found")
    endif()
endif()

if(ENABLE_CPPCHECK)
    find_program(CPPCHECK cppcheck)
    if(CPPCHECK)
        set(CMAKE_CXX_CPPCHECK 
            ${CPPCHECK}
            --suppress=missingInclude
            --enable=all
            --inline-suppr
            --inconclusive
        )
        message(STATUS "🔍 cppcheck enabled")
    else()
        message(SEND_ERROR "🔍 cppcheck requested but not found")
    endif()
endif()
ANALYSIS_EOF
    
    # vcpkg helper functions
    cat > cmake/VcpkgHelpers.cmake << 'VCPKG_HELPERS_EOF'
# 📦 vcpkg Helper Functions
# Automatically finds and links packages from vcpkg.json

# Global variables to store found packages and their targets
set(VCPKG_FOUND_PACKAGES "" CACHE INTERNAL "List of found vcpkg packages")
set(VCPKG_PACKAGE_TARGETS "" CACHE INTERNAL "List of vcpkg package targets")

# Helper function to extract package info using jq
function(vcpkg_extract_package_info PKG_JSON_STRING RESULT_NAME RESULT_FEATURES)
    find_program(JQ_EXECUTABLE jq)
    if(NOT JQ_EXECUTABLE)
        set(${RESULT_NAME} "${PKG_JSON_STRING}" PARENT_SCOPE)
        set(${RESULT_FEATURES} "" PARENT_SCOPE)
        return()
    endif()
    
    # Check if it's a JSON object
    if(PKG_JSON_STRING MATCHES "^{.*}$")
        # Extract name
        execute_process(
            COMMAND echo "${PKG_JSON_STRING}"
            COMMAND ${JQ_EXECUTABLE} -r ".name // empty"
            OUTPUT_VARIABLE PKG_NAME
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        
        # Extract features
        execute_process(
            COMMAND echo "${PKG_JSON_STRING}"
            COMMAND ${JQ_EXECUTABLE} -r ".features[]? // empty"
            OUTPUT_VARIABLE PKG_FEATURES_RAW
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        
        # Convert features to list
        string(REPLACE "\n" ";" PKG_FEATURES "${PKG_FEATURES_RAW}")
        
        set(${RESULT_NAME} "${PKG_NAME}" PARENT_SCOPE)
        set(${RESULT_FEATURES} "${PKG_FEATURES}" PARENT_SCOPE)
    else()
        # Simple string dependency
        set(${RESULT_NAME} "${PKG_JSON_STRING}" PARENT_SCOPE)
        set(${RESULT_FEATURES} "" PARENT_SCOPE)
    endif()
endfunction()

# Function to parse vcpkg.json and find packages automatically
function(vcpkg_find_packages)
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/vcpkg.json")
        message(WARNING "📦 vcpkg.json not found, skipping automatic package discovery")
        return()
    endif()
    
    message(STATUS "📦 Parsing vcpkg.json for automatic package discovery...")
    
    # Read vcpkg.json file
    file(READ "${CMAKE_CURRENT_SOURCE_DIR}/vcpkg.json" VCPKG_JSON_CONTENT)
    
    # Define package mappings for known packages (package-name -> find_package name and target)
    set(KNOWN_PACKAGE_MAPPINGS
        "fmt;fmt;fmt::fmt"
        "spdlog;spdlog;spdlog::spdlog"
        "catch2;Catch2;Catch2::Catch2WithMain"
        "boost;Boost;Boost::boost"
        "opencv;OpenCV;opencv_core"
        "eigen3;Eigen3;Eigen3::Eigen"
        "nlohmann-json;nlohmann_json;nlohmann_json::nlohmann_json"
        "glfw3;glfw3;glfw"
        "opengl;OpenGL;OpenGL::GL"
        "vulkan;Vulkan;Vulkan::Vulkan"
        "asio;asio;asio::asio"
        "protobuf;Protobuf;protobuf::libprotobuf"
        "grpc;gRPC;gRPC::grpc++"
        "sqlite3;SQLite3;SQLite::SQLite3"
        "curl;CURL;CURL::libcurl"
        "zlib;ZLIB;ZLIB::ZLIB"
        "openssl;OpenSSL;OpenSSL::SSL"
        "gtest;GTest;GTest::gtest"
        "benchmark;benchmark;benchmark::benchmark"
        "tbb;TBB;TBB::tbb"
        "imgui;imgui;imgui::imgui"
        "sdl2;SDL2;SDL2::SDL2"
        "sfml;SFML;sfml-graphics"
    )
    
    # Extract all dependencies from JSON using jq
    # Check if jq is available
    find_program(JQ_EXECUTABLE jq)
    if(NOT JQ_EXECUTABLE)
        message(WARNING "📦 jq not found for JSON parsing")
        message(STATUS "📦 Install jq for better dependency discovery:")
        message(STATUS "📦   macOS: brew install jq")
        message(STATUS "📦   Ubuntu: sudo apt-get install jq")
        message(STATUS "📦   Arch: sudo pacman -S jq")
        message(STATUS "📦 Falling back to basic dependency discovery")
        return()
    endif()
    
    message(STATUS "📦 Using jq for smart JSON parsing")
    
    # Use jq to extract dependencies
    execute_process(
        COMMAND ${JQ_EXECUTABLE} -r ".dependencies[]?" "${CMAKE_CURRENT_SOURCE_DIR}/vcpkg.json"
        OUTPUT_VARIABLE DEPS_OUTPUT
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    
    # Convert output to list
    string(REPLACE "\n" ";" ALL_DEPS "${DEPS_OUTPUT}")
    
    set(FOUND_PACKAGES "")
    set(PACKAGE_TARGETS "")
    
    # Process each dependency found in vcpkg.json
    foreach(PKG_ENTRY ${ALL_DEPS})
        # Skip empty strings
        if(NOT PKG_ENTRY)
            continue()
        endif()
        
        # Extract package name and features using helper function
        vcpkg_extract_package_info("${PKG_ENTRY}" PKG_NAME PKG_FEATURES)
        
        # Skip if no valid package name
        if(NOT PKG_NAME)
            continue()
        endif()
        
        if(PKG_FEATURES)
            message(STATUS "📦 Processing package: ${PKG_NAME} [${PKG_FEATURES}]")
        else()
            message(STATUS "📦 Processing package: ${PKG_NAME}")
        endif()
        
        # First, check if we have a known mapping
        set(FIND_NAME "")
        set(TARGET_NAME "")
        set(FOUND_MAPPING FALSE)
        
        # Check custom mappings first
        if(DEFINED VCPKG_CUSTOM_MAPPINGS)
            foreach(CUSTOM_MAPPING ${VCPKG_CUSTOM_MAPPINGS})
                string(REPLACE ";" "|" MAPPING_ESCAPED "${CUSTOM_MAPPING}")
                string(REGEX MATCH "([^|]+)\\|([^|]+)\\|([^|]+)" MATCH_RESULT "${MAPPING_ESCAPED}")
                
                if(MATCH_RESULT AND CMAKE_MATCH_1 STREQUAL PKG_NAME)
                    set(FIND_NAME "${CMAKE_MATCH_2}")
                    set(TARGET_NAME "${CMAKE_MATCH_3}")
                    set(FOUND_MAPPING TRUE)
                    message(STATUS "  ✅ Using custom mapping: ${PKG_NAME} -> ${FIND_NAME}")
                    break()
                endif()
            endforeach()
        endif()
        
        # If no custom mapping, check known mappings
        if(NOT FOUND_MAPPING)
            foreach(MAPPING ${KNOWN_PACKAGE_MAPPINGS})
                string(REPLACE ";" "|" MAPPING_ESCAPED "${MAPPING}")
                string(REGEX MATCH "([^|]+)\\|([^|]+)\\|([^|]+)" MATCH_RESULT "${MAPPING_ESCAPED}")
                
                if(MATCH_RESULT AND CMAKE_MATCH_1 STREQUAL PKG_NAME)
                    set(FIND_NAME "${CMAKE_MATCH_2}")
                    set(TARGET_NAME "${CMAKE_MATCH_3}")
                    set(FOUND_MAPPING TRUE)
                    message(STATUS "  ✅ Using known mapping: ${PKG_NAME} -> ${FIND_NAME}")
                    break()
                endif()
            endforeach()
        endif()
        
        # If no known mapping, try intelligent guessing
        if(NOT FOUND_MAPPING)
            message(STATUS "  🔍 No known mapping, trying intelligent discovery...")
            
            # Common naming patterns for find_package
            set(POSSIBLE_FIND_NAMES 
                "${PKG_NAME}"                    # exact match
                "${PKG_NAME}Config"              # with Config suffix
                "${PKG_NAME}Targets"             # with Targets suffix
            )
            
            # Try different case variations
            string(TOUPPER "${PKG_NAME}" PKG_UPPER)
            string(TOLOWER "${PKG_NAME}" PKG_LOWER)
            string(SUBSTRING "${PKG_NAME}" 0 1 FIRST_CHAR)
            string(TOUPPER "${FIRST_CHAR}" FIRST_UPPER)
            string(SUBSTRING "${PKG_NAME}" 1 -1 REST_CHARS)
            string(TOLOWER "${REST_CHARS}" REST_LOWER)
            set(PKG_TITLE_CASE "${FIRST_UPPER}${REST_LOWER}")
            
            list(APPEND POSSIBLE_FIND_NAMES 
                "${PKG_UPPER}" "${PKG_LOWER}" "${PKG_TITLE_CASE}"
                "${PKG_UPPER}Config" "${PKG_TITLE_CASE}Config"
            )
            
            # Try to find the package with different names
            foreach(FIND_ATTEMPT ${POSSIBLE_FIND_NAMES})
                find_package(${FIND_ATTEMPT} CONFIG QUIET)
                if(${FIND_ATTEMPT}_FOUND)
                    set(FIND_NAME "${FIND_ATTEMPT}")
                    message(STATUS "  ✅ Found with name: ${FIND_ATTEMPT}")
                    break()
                endif()
            endforeach()
            
            # If found, try to guess the target name
            if(FIND_NAME)
                set(POSSIBLE_TARGETS
                    "${PKG_NAME}::${PKG_NAME}"
                    "${PKG_LOWER}::${PKG_LOWER}"
                    "${PKG_TITLE_CASE}::${PKG_TITLE_CASE}"
                    "${PKG_UPPER}::${PKG_UPPER}"
                    "${PKG_NAME}"
                    "${PKG_LOWER}"
                    "${PKG_TITLE_CASE}"
                    "${PKG_UPPER}"
                )
                
                foreach(TARGET_ATTEMPT ${POSSIBLE_TARGETS})
                    if(TARGET ${TARGET_ATTEMPT})
                        set(TARGET_NAME "${TARGET_ATTEMPT}")
                        message(STATUS "  ✅ Found target: ${TARGET_ATTEMPT}")
                        break()
                    endif()
                endforeach()
                
                # If no target found, use the first possible target name
                if(NOT TARGET_NAME)
                    list(GET POSSIBLE_TARGETS 0 TARGET_NAME)
                    message(STATUS "  ⚠️  No target found, using fallback: ${TARGET_NAME}")
                endif()
            endif()
        else()
            # Use known mapping, try to find the package
            find_package(${FIND_NAME} CONFIG QUIET)
            if(${FIND_NAME}_FOUND)
                message(STATUS "  ✅ Found package: ${FIND_NAME}")
            endif()
        endif()
        
        # Try to find the package if we have a find name but haven't found it yet
        if(FIND_NAME AND NOT ${FIND_NAME}_FOUND)
            find_package(${FIND_NAME} CONFIG QUIET)
        endif()
        
        # Check if package was successfully found
        if(FIND_NAME AND (${FIND_NAME}_FOUND OR TARGET ${TARGET_NAME}))
            message(STATUS "  ✅ Successfully configured: ${PKG_NAME} -> ${TARGET_NAME}")
            list(APPEND FOUND_PACKAGES "${PKG_NAME}")
            list(APPEND PACKAGE_TARGETS "${TARGET_NAME}")
        else()
            message(WARNING "  ⚠️  Could not configure package: ${PKG_NAME}")
            message(STATUS "  💡 You may need to add manual find_package() and target_link_libraries() for this package")
        endif()
    endforeach()
    
    # Store results in cache
    set(VCPKG_FOUND_PACKAGES "${FOUND_PACKAGES}" CACHE INTERNAL "List of found vcpkg packages")
    set(VCPKG_PACKAGE_TARGETS "${PACKAGE_TARGETS}" CACHE INTERNAL "List of vcpkg package targets")
    
    list(LENGTH FOUND_PACKAGES NUM_FOUND)
    if(NUM_FOUND GREATER 0)
        message(STATUS "📦 Successfully configured ${NUM_FOUND} packages from vcpkg.json")
        message(STATUS "📦 Found packages: ${FOUND_PACKAGES}")
    else()
        message(STATUS "📦 No packages could be automatically configured from vcpkg.json")
    endif()
endfunction()

# Function to automatically link all found vcpkg packages to a target
function(vcpkg_link_libraries TARGET_NAME VISIBILITY)
    if(NOT VCPKG_PACKAGE_TARGETS)
        message(STATUS "📦 No vcpkg packages to link to ${TARGET_NAME}")
        return()
    endif()
    
    message(STATUS "📦 Linking vcpkg packages to ${TARGET_NAME} (${VISIBILITY})")
    
    foreach(TARGET_LIB ${VCPKG_PACKAGE_TARGETS})
        if(TARGET ${TARGET_LIB})
            target_link_libraries(${TARGET_NAME} ${VISIBILITY} ${TARGET_LIB})
            message(STATUS "  ✅ Linked: ${TARGET_LIB}")
        else()
            message(WARNING "  ⚠️  Target not available: ${TARGET_LIB}")
        endif()
    endforeach()
endfunction()

# Function to link specific vcpkg packages to a target
function(vcpkg_link_specific TARGET_NAME VISIBILITY)
    set(PACKAGES ${ARGN})
    
    if(NOT PACKAGES)
        message(WARNING "📦 No packages specified for vcpkg_link_specific")
        return()
    endif()
    
    message(STATUS "📦 Linking specific packages to ${TARGET_NAME}: ${PACKAGES}")
    
    foreach(PKG ${PACKAGES})
        # Find the target for this package
        list(FIND VCPKG_FOUND_PACKAGES "${PKG}" PKG_INDEX)
        if(PKG_INDEX GREATER_EQUAL 0)
            list(GET VCPKG_PACKAGE_TARGETS ${PKG_INDEX} TARGET_LIB)
            if(TARGET ${TARGET_LIB})
                target_link_libraries(${TARGET_NAME} ${VISIBILITY} ${TARGET_LIB})
                message(STATUS "  ✅ Linked: ${PKG} -> ${TARGET_LIB}")
            else()
                message(WARNING "  ⚠️  Target not available: ${TARGET_LIB}")
            endif()
        else()
            message(WARNING "  ⚠️  Package not found: ${PKG}")
        endif()
    endforeach()
endfunction()

# Function to get list of available packages
function(vcpkg_list_packages)
    if(VCPKG_FOUND_PACKAGES)
        message(STATUS "📦 Available vcpkg packages:")
        foreach(PKG ${VCPKG_FOUND_PACKAGES})
            message(STATUS "  • ${PKG}")
        endforeach()
    else()
        message(STATUS "📦 No vcpkg packages available")
    endif()
endfunction()

# Function to check if a specific package is available
function(vcpkg_has_package PACKAGE_NAME RESULT_VAR)
    list(FIND VCPKG_FOUND_PACKAGES "${PACKAGE_NAME}" PKG_INDEX)
    if(PKG_INDEX GREATER_EQUAL 0)
        set(${RESULT_VAR} TRUE PARENT_SCOPE)
    else()
        set(${RESULT_VAR} FALSE PARENT_SCOPE)
    endif()
endfunction()

# Function to add custom package mappings
function(vcpkg_add_package_mapping PACKAGE_NAME FIND_NAME TARGET_NAME)
    if(NOT DEFINED VCPKG_CUSTOM_MAPPINGS)
        set(VCPKG_CUSTOM_MAPPINGS "" CACHE INTERNAL "Custom vcpkg package mappings")
    endif()
    
    set(NEW_MAPPING "${PACKAGE_NAME};${FIND_NAME};${TARGET_NAME}")
    list(APPEND VCPKG_CUSTOM_MAPPINGS "${NEW_MAPPING}")
    set(VCPKG_CUSTOM_MAPPINGS "${VCPKG_CUSTOM_MAPPINGS}" CACHE INTERNAL "Custom vcpkg package mappings")
    
    message(STATUS "📦 Added custom mapping: ${PACKAGE_NAME} -> ${FIND_NAME} -> ${TARGET_NAME}")
endfunction()

VCPKG_HELPERS_EOF
    
    log_success "CMake configuration created"
}

create_source_files() {
    log_header "Creating Source Files"
    
    if [[ "$PROJECT_TYPE" == "console" ]]; then
        cat > src/main.cpp << 'MAIN_EOF'
#include <iostream>
#include <vector>
#include <ranges>
#include <algorithm>
#include <string>

#ifdef USE_VCPKG
#include <fmt/format.h>
#include <spdlog/spdlog.h>
#endif

// 🔥 C++20 Concepts example
template<typename T>
concept Numeric = std::integral<T> || std::floating_point<T>;

template<Numeric T>
constexpr T square(T value) noexcept {
    return value * value;
}

// 🌊 C++20 Ranges example
auto process_numbers(const std::vector<int>& numbers) {
    return numbers 
        | std::views::filter([](int n) { return n > 0; })
        | std::views::transform(square<int>)
        | std::views::take(10);
}

int main() {
    #ifdef USE_VCPKG
    spdlog::info("🚀 Starting modern C++20 application");
    #else
    std::cout << "🚀 Starting modern C++20 application\n";
    #endif
    
    // Demo data
    std::vector<int> numbers{-2, 1, -3, 4, -5, 6, 7, -8, 9, 10, 11, 12};
    
    #ifdef USE_VCPKG
    spdlog::info("Original numbers: {}", fmt::join(numbers, ", "));
    #else
    std::cout << "Original numbers: ";
    for (auto n : numbers) std::cout << n << " ";
    std::cout << "\n";
    #endif
    
    // Process using C++20 ranges
    auto processed = process_numbers(numbers);
    
    #ifdef USE_VCPKG
    std::vector<int> result(processed.begin(), processed.end());
    spdlog::info("Processed (positive, squared, first 10): {}", fmt::join(result, ", "));
    #else
    std::cout << "Processed (positive, squared, first 10): ";
    for (auto n : processed) std::cout << n << " ";
    std::cout << "\n";
    #endif
    
    // C++20 designated initializers
    struct Config {
        std::string name;
        int version;
        bool debug_mode;
    };
    
    auto config = Config{
        .name = "MyApp",
        .version = 1,
        .debug_mode = true
    };
    
    #ifdef USE_VCPKG
    spdlog::info("Config: {} v{} (debug: {})", config.name, config.version, config.debug_mode);
    #else
    std::cout << "Config: " << config.name << " v" << config.version 
              << " (debug: " << std::boolalpha << config.debug_mode << ")\n";
    #endif
    
    #ifdef USE_VCPKG
    spdlog::info("✅ Application completed successfully!");
    #else
    std::cout << "✅ Application completed successfully!\n";
    #endif
    
    return 0;
}
MAIN_EOF
    elif [[ "$PROJECT_TYPE" == "library" ]]; then
        # Header file
        cat > include/"$PROJECT_NAME"/"$PROJECT_NAME".hpp << LIB_HEADER_EOF
#pragma once

#include <vector>
#include <concepts>

namespace ${PROJECT_NAME} {

// 🔥 C++20 Concepts
template<typename T>
concept Numeric = std::integral<T> || std::floating_point<T>;

// 🎯 Main library class
class Calculator {
public:
    Calculator() = default;
    ~Calculator() = default;
    
    // Non-copyable, movable
    Calculator(const Calculator&) = delete;
    Calculator& operator=(const Calculator&) = delete;
    Calculator(Calculator&&) = default;
    Calculator& operator=(Calculator&&) = default;
    
    // 🧮 Mathematical operations
    template<Numeric T>
    constexpr T add(T a, T b) noexcept {
        return a + b;
    }
    
    template<Numeric T>
    constexpr T multiply(T a, T b) noexcept {
        return a * b;
    }
    
    // 📊 Vector operations
    template<Numeric T>
    std::vector<T> process_vector(const std::vector<T>& input);
    
private:
    static constexpr double PI = 3.14159265358979323846;
};

// 🌊 Utility functions using ranges
template<Numeric T>
auto sum_positive(const std::vector<T>& numbers) -> T;

template<Numeric T>
auto filter_and_transform(const std::vector<T>& numbers) -> std::vector<T>;

} // namespace ${PROJECT_NAME}
LIB_HEADER_EOF
        
        # Implementation file
        cat > src/"$PROJECT_NAME".cpp << LIB_IMPL_EOF
#include "${PROJECT_NAME}/${PROJECT_NAME}.hpp"
#include <ranges>
#include <algorithm>
#include <numeric>

namespace ${PROJECT_NAME} {

template<Numeric T>
std::vector<T> Calculator::process_vector(const std::vector<T>& input) {
    std::vector<T> result;
    result.reserve(input.size());
    
    // Use C++20 ranges
    auto processed = input 
        | std::views::filter([](const T& x) { return x > T{0}; })
        | std::views::transform([](const T& x) { return x * x; });
    
    std::ranges::copy(processed, std::back_inserter(result));
    return result;
}

template<Numeric T>
auto sum_positive(const std::vector<T>& numbers) -> T {
    auto positive_numbers = numbers | std::views::filter([](const T& n) { return n > T{0}; });
    return std::accumulate(positive_numbers.begin(), positive_numbers.end(), T{0});
}

template<Numeric T>
auto filter_and_transform(const std::vector<T>& numbers) -> std::vector<T> {
    auto transformed = numbers 
        | std::views::filter([](const T& n) { return n % 2 == 0; })
        | std::views::transform([](const T& n) { return n * 3; });
    
    std::vector<T> result;
    std::ranges::copy(transformed, std::back_inserter(result));
    return result;
}

// Explicit template instantiations
template class Calculator;
template auto sum_positive<int>(const std::vector<int>&) -> int;
template auto sum_positive<double>(const std::vector<double>&) -> double;
template auto filter_and_transform<int>(const std::vector<int>&) -> std::vector<int>;

} // namespace ${PROJECT_NAME}
LIB_IMPL_EOF
        
        # Example usage
        mkdir -p examples
        cat > examples/example.cpp << EXAMPLE_EOF
#include "${PROJECT_NAME}/${PROJECT_NAME}.hpp"
#include <iostream>
#include <vector>

int main() {
    std::cout << "🚀 ${PROJECT_NAME} Library Example\n";
    
    ${PROJECT_NAME}::Calculator calc;
    
    // Basic operations
    auto sum = calc.add(5, 3);
    auto product = calc.multiply(4, 7);
    
    std::cout << "5 + 3 = " << sum << std::endl;
    std::cout << "4 * 7 = " << product << std::endl;
    
    // Vector operations
    std::vector<int> numbers{-2, 3, -4, 5, 6, -7, 8};
    
    std::cout << "Original: ";
    for (auto n : numbers) std::cout << n << " ";
    std::cout << std::endl;
    
    auto processed = calc.process_vector(numbers);
    
    std::cout << "Processed (positive squared): ";
    for (auto n : processed) std::cout << n << " ";
    std::cout << std::endl;
    
    // Utility functions
    auto positive_sum = ${PROJECT_NAME}::sum_positive(numbers);
    std::cout << "Sum of positive: " << positive_sum << std::endl;
    
    return 0;
}
EXAMPLE_EOF
    fi
    
    log_success "Source files created"
}

create_test_files() {
    if [[ "$USE_TESTING" == "true" ]]; then
        log_header "Creating Test Files"
        
        # Test CMakeLists.txt
        cat > tests/CMakeLists.txt << TEST_CMAKE_EOF
# 🧪 Testing configuration
find_package(Catch2 3 QUIET)

if(NOT Catch2_FOUND)
    # Fallback: Use FetchContent to get Catch2
    include(FetchContent)
    FetchContent_Declare(
        Catch2
        GIT_REPOSITORY https://github.com/catchorg/Catch2.git
        GIT_TAG v3.4.0
    )
    FetchContent_MakeAvailable(Catch2)
endif()

# Test executable
add_executable(${PROJECT_NAME}_tests
    test_main.cpp
    test_${PROJECT_NAME}.cpp
)

target_link_libraries(${PROJECT_NAME}_tests PRIVATE
    Catch2::Catch2WithMain
)

# Link library for library projects
if [[ "$PROJECT_TYPE" == "library" ]]; then
    cat >> tests/CMakeLists.txt << TEST_LIBRARY_LINK_EOF

target_link_libraries(${PROJECT_NAME}_tests PRIVATE ${PROJECT_NAME})
TEST_LIBRARY_LINK_EOF
fi

# Enable testing
include(CTest)

# Add test manually (simple and reliable approach)
add_test(NAME ${PROJECT_NAME}_tests COMMAND ${PROJECT_NAME}_tests)
TEST_CMAKE_EOF
        
        # Test main file
        cat > tests/test_main.cpp << TEST_MAIN_EOF
#include <catch2/catch_test_macros.hpp>

// This file can be used for global test setup if needed
// Catch2 v3 with Catch2::Catch2WithMain handles main() automatically
TEST_MAIN_EOF
        
        if [[ "$PROJECT_TYPE" == "library" ]]; then
            cat > tests/test_"$PROJECT_NAME".cpp << TEST_LIB_EOF
#include <catch2/catch_test_macros.hpp>
#include "${PROJECT_NAME}/${PROJECT_NAME}.hpp"
#include <vector>

using namespace ${PROJECT_NAME};

TEST_CASE("Calculator basic operations", "[calculator]") {
    Calculator calc;
    
    SECTION("Addition") {
        REQUIRE(calc.add(2, 3) == 5);
        REQUIRE(calc.add(-1, 1) == 0);
        REQUIRE(calc.add(0, 0) == 0);
    }
    
    SECTION("Multiplication") {
        REQUIRE(calc.multiply(3, 4) == 12);
        REQUIRE(calc.multiply(-2, 3) == -6);
        REQUIRE(calc.multiply(0, 100) == 0);
    }
}

TEST_CASE("Vector processing", "[vector]") {
    Calculator calc;
    
    SECTION("Process vector with positive numbers") {
        std::vector<int> input{-2, 3, -4, 5};
        auto result = calc.process_vector(input);
        
        // Should contain squares of positive numbers: 9, 25
        REQUIRE(result.size() == 2);
        REQUIRE(result[0] == 9);   // 3^2
        REQUIRE(result[1] == 25);  // 5^2
    }
    
    SECTION("Process empty vector") {
        std::vector<int> input{};
        auto result = calc.process_vector(input);
        REQUIRE(result.empty());
    }
}

TEST_CASE("Utility functions", "[utilities]") {
    SECTION("Sum positive numbers") {
        std::vector<int> numbers{-2, 3, -4, 5, 6};
        auto result = sum_positive(numbers);
        REQUIRE(result == 14);  // 3 + 5 + 6
    }
    
    SECTION("Filter and transform") {
        std::vector<int> numbers{1, 2, 3, 4, 5, 6};
        auto result = filter_and_transform(numbers);
        
        // Even numbers * 3: 2*3=6, 4*3=12, 6*3=18
        REQUIRE(result.size() == 3);
        REQUIRE(result[0] == 6);
        REQUIRE(result[1] == 12);
        REQUIRE(result[2] == 18);
    }
}

TEST_CASE("C++20 Concepts", "[concepts]") {
    Calculator calc;
    
    SECTION("Works with different numeric types") {
        // Integer types
        REQUIRE(calc.add(1, 2) == 3);
        REQUIRE(calc.add(1L, 2L) == 3L);
        
        // Floating point types
        REQUIRE(calc.add(1.5, 2.5) == 4.0);
        REQUIRE(calc.add(1.5f, 2.5f) == 4.0f);
    }
}
TEST_LIB_EOF
        else
            # Console app test
            cat > tests/test_"$PROJECT_NAME".cpp << TEST_CONSOLE_EOF
#include <catch2/catch_test_macros.hpp>
#include <vector>
#include <ranges>

// Example tests for console application
// You would typically test your business logic functions here

// Mock function from main.cpp (you'd need to extract this to a header)
template<typename T>
concept Numeric = std::integral<T> || std::floating_point<T>;

template<Numeric T>
constexpr T square(T value) noexcept {
    return value * value;
}

TEST_CASE("Square function", "[math]") {
    SECTION("Integer squares") {
        REQUIRE(square(0) == 0);
        REQUIRE(square(1) == 1);
        REQUIRE(square(2) == 4);
        REQUIRE(square(-3) == 9);
    }
    
    SECTION("Floating point squares") {
        REQUIRE(square(1.5) == 2.25);
        REQUIRE(square(-2.0) == 4.0);
    }
}

TEST_CASE("C++20 Ranges processing", "[ranges]") {
    std::vector<int> numbers{-2, 1, -3, 4, -5, 6};
    
    auto processed = numbers 
        | std::views::filter([](int n) { return n > 0; })
        | std::views::transform(square<int>);
    
    std::vector<int> result(processed.begin(), processed.end());
    
    REQUIRE(result.size() == 3);  // 1, 4, 6 are positive
    REQUIRE(result[0] == 1);      // 1^2
    REQUIRE(result[1] == 16);     // 4^2  
    REQUIRE(result[2] == 36);     // 6^2
}
TEST_CONSOLE_EOF
        fi
        
        log_success "Test files created"
    fi
}

create_vcpkg_config() {
    if [[ "$USE_VCPKG" == "true" ]]; then
        log_header "Creating vcpkg Configuration"
        
        local deps='"fmt", "spdlog"'
        [[ "$USE_TESTING" == "true" ]] && deps+=', "catch2"'
        
        cat > vcpkg.json << VCPKG_EOF
{
  "name": "${PROJECT_NAME}",
  "version": "1.0.0",
  "description": "Modern C++20 ${PROJECT_TYPE} project",
  "homepage": "https://github.com/your-username/${PROJECT_NAME}",
  "dependencies": [
    ${deps}
  ],
  "builtin-baseline": "$(git ls-remote https://github.com/Microsoft/vcpkg.git HEAD | cut -f1)"
}
VCPKG_EOF
        
        log_success "vcpkg configuration created"
    fi
}

create_build_scripts() {
    log_header "Creating Build Scripts"
    
    # Main build script
    cat > scripts/build.sh << 'BUILD_EOF'
#!/bin/bash

set -euo pipefail

# 🎨 Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

BUILD_TYPE="${1:-Release}"
RUN_TESTS="${2:-true}"

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}" >&2; }

# Validate build type
case $BUILD_TYPE in
    Debug|Release|RelWithDebInfo|MinSizeRel) ;;
    *) log_error "Invalid build type: $BUILD_TYPE"; exit 1 ;;
esac

log_info "Building in $BUILD_TYPE mode..."

# Configure
CMAKE_ARGS=(
    -B build
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
    -DENABLE_TESTING=ON
    -G Ninja
)

# Add vcpkg toolchain if available
if [[ -n "${VCPKG_ROOT:-}" ]] && [[ -f "$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" ]]; then
    CMAKE_ARGS+=(-DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake")
    log_info "Using vcpkg toolchain"
    
    # Install vcpkg dependencies if vcpkg.json exists
    if [[ -f "vcpkg.json" ]] && command -v vcpkg &>/dev/null; then
        log_info "Installing vcpkg dependencies..."
        vcpkg install
        log_success "vcpkg dependencies installed"
    fi
fi

cmake "${CMAKE_ARGS[@]}"

# Build
log_info "Building project..."
cmake --build build --parallel

# Test
if [[ "$RUN_TESTS" == "true" ]] && [[ -d "tests" ]]; then
    log_info "Running tests..."
    cd build
    ctest --output-on-failure --parallel
    cd ..
fi

log_success "Build completed successfully!"

# Show binary info
if [[ -f "build/${PROJECT_NAME}" ]]; then
    echo
    log_info "Binary information:"
    echo "  📄 Size: $(du -h "build/${PROJECT_NAME}" | cut -f1)"
    echo "  🏗️  Type: $(file "build/${PROJECT_NAME}" | cut -d: -f2)"
fi
BUILD_EOF
    
    # Development script
    cat > scripts/dev.sh << 'DEV_EOF'
#!/bin/bash

# 🔧 Development helper script
set -euo pipefail

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }

case "${1:-help}" in
    "build")
        log_info "Building in debug mode..."
        ./scripts/build.sh Debug
        ;;
    "test")
        log_info "Running tests..."
        cd build && ctest --output-on-failure
        ;;
    "clean")
        log_info "Cleaning build directory..."
        rm -rf build
        ;;
    "format")
        if command -v clang-format &>/dev/null; then
            log_info "Formatting code..."
            find src include tests -name "*.cpp" -o -name "*.hpp" | xargs clang-format -i
            log_success "Code formatted"
        else
            echo "clang-format not found"
        fi
        ;;
    "analyze")
        if command -v clang-tidy &>/dev/null; then
            log_info "Running static analysis..."
            cmake -B build -DENABLE_CLANG_TIDY=ON
            cmake --build build
        else
            echo "clang-tidy not found"
        fi
        ;;
    *)
        echo "🔧 Development helper"
        echo "Usage: $0 {build|test|clean|format|analyze}"
        echo ""
        echo "Commands:"
        echo "  build   - Build in debug mode"
        echo "  test    - Run tests"
        echo "  clean   - Clean build directory"
        echo "  format  - Format code with clang-format"
        echo "  analyze - Run static analysis"
        ;;
esac
DEV_EOF
    
    chmod +x scripts/*.sh
    
    log_success "Build scripts created"
}

create_ci_config() {
    log_header "Creating CI/CD Configuration"
    
    cat > .github/workflows/ci.yml << 'CI_EOF'
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        build_type: [Debug, Release]
        
    steps:
    - uses: actions/checkout@v4
    
    - name: Install dependencies (Ubuntu)
      if: runner.os == 'Linux'
      run: |
        sudo apt-get update
        sudo apt-get install -y cmake ninja-build clang
        
    - name: Install dependencies (macOS)
      if: runner.os == 'macOS'
      run: |
        brew install cmake ninja llvm
        
    - name: Setup vcpkg
      uses: lukka/run-vcpkg@v11
      with:
        vcpkgGitCommitId: '${{ env.VCPKG_COMMIT_ID }}'
        
    - name: Configure CMake
      run: |
        cmake -B build \
          -DCMAKE_BUILD_TYPE=${{ matrix.build_type }} \
          -DENABLE_TESTING=ON \
          -DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake \
          -G Ninja
          
    - name: Build
      run: cmake --build build --parallel
      
    - name: Test
      run: cd build && ctest --output-on-failure --parallel
CI_EOF
    
    log_success "CI/CD configuration created"
}

create_documentation() {
    log_header "Creating Documentation"
    
    cat > README.md << README_EOF
# ${PROJECT_NAME}

Modern C++20 ${PROJECT_TYPE} project with best practices.

## Features

- 🚀 **C++20**: Uses modern C++20 features (concepts, ranges, coroutines)
- 📦 **Package Management**: vcpkg integration for dependencies  
- 🧪 **Testing**: Catch2 testing framework
- 🔧 **Build System**: CMake with Ninja generator
- 🔍 **Static Analysis**: Optional clang-tidy integration
- 🎨 **Code Formatting**: clang-format configuration
- 🤖 **CI/CD**: GitHub Actions workflow

## Requirements

- CMake 3.25+
- C++20 compatible compiler (GCC 10+, Clang 10+, MSVC 2019+)
- vcpkg (optional but recommended)

## Quick Start

### Build and Run

\`\`\`bash
# Build in release mode
./scripts/build.sh Release

# Build and run tests  
./scripts/build.sh Debug true
\`\`\`

### Development

\`\`\`bash
# Development commands
./scripts/dev.sh build    # Debug build
./scripts/dev.sh test     # Run tests
./scripts/dev.sh format   # Format code
./scripts/dev.sh analyze  # Static analysis
./scripts/dev.sh clean    # Clean build
\`\`\`

## Project Structure

\`\`\`
${PROJECT_NAME}/
├── src/                 # Source files
├── include/             # Header files
├── tests/               # Test files
├── scripts/             # Build scripts
├── docs/                # Documentation
├── .github/workflows/   # CI/CD
├── CMakeLists.txt      # CMake configuration
└── vcpkg.json          # Package manifest
\`\`\`

## Dependencies

$(if [[ "$USE_VCPKG" == "true" ]]; then
echo "This project uses vcpkg with **automatic package discovery** from \`vcpkg.json\`:

### 📦 vcpkg Helper Functions

The project includes smart CMake helper functions that automatically:
- Parse \`vcpkg.json\` to discover dependencies
- Call \`find_package()\` for each dependency
- Link libraries to targets automatically

### Available Functions

\`\`\`cmake
# Automatically find all packages from vcpkg.json
vcpkg_find_packages()

# Link all found packages to a target
vcpkg_link_libraries(target_name PRIVATE|PUBLIC)

# Link specific packages only
vcpkg_link_specific(target_name PRIVATE|PUBLIC package1 package2...)

# Check if package is available
vcpkg_has_package(package_name result_var)

# List all available packages
vcpkg_list_packages()
\`\`\`

### Supported Packages

The helper functions support common packages like:
- **fmt**: Modern formatting library
- **spdlog**: Fast logging library"
if [[ "$USE_TESTING" == "true" ]]; then
echo "- **Catch2**: Testing framework"
fi
echo "- **boost**: Boost libraries
- **opencv**: Computer vision library
- **eigen3**: Linear algebra library
- **nlohmann-json**: JSON library
- **And many more...**

### Adding New Dependencies

1. Add package to \`vcpkg.json\`:
\`\`\`json
{
  \"dependencies\": [
    \"fmt\",
    \"spdlog\",
    \"your-new-package\"
  ]
}
\`\`\`

2. The helper functions will automatically discover and link it!

**How it works:**
- ✅ **Known packages** (fmt, spdlog, boost, etc.) use pre-defined mappings
- 🔍 **Unknown packages** are discovered using intelligent naming patterns
- 🔧 **Complex packages** can use custom mappings:

\`\`\`cmake
# For packages with non-standard naming
vcpkg_add_package_mapping(weird-lib WeirdLibrary WeirdLibrary::core)
vcpkg_find_packages()
\`\`\`

**No manual \`find_package()\` or \`target_link_libraries()\` needed!**"
fi)

## Building

### With vcpkg (Recommended)

\`\`\`bash
# Install vcpkg if not already installed
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg && ./bootstrap-vcpkg.sh
export VCPKG_ROOT=\$(pwd)

# Build project
cmake -B build -DCMAKE_TOOLCHAIN_FILE=\$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
cmake --build build
\`\`\`

### Manual Dependencies

If you prefer to manage dependencies manually, disable vcpkg:

\`\`\`bash
cmake -B build -DUSE_VCPKG=OFF
cmake --build build
\`\`\`

## Testing

\`\`\`bash
# Run all tests
cd build && ctest

# Run with verbose output
cd build && ctest --verbose

# Run specific test
cd build && ctest -R "test_name"
\`\`\`

## Code Quality

### Formatting

\`\`\`bash
# Format all code
./scripts/dev.sh format
\`\`\`

### Static Analysis

\`\`\`bash
# Run clang-tidy
./scripts/dev.sh analyze
\`\`\`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
README_EOF
    
    # Create basic docs
    cat > docs/API.md << 'API_EOF'
# API Documentation

## Overview

This document describes the public API of the library and the vcpkg helper functions.

## 📦 vcpkg Helper Functions

### vcpkg_find_packages()

Automatically parses `vcpkg.json` and calls `find_package()` for all dependencies.

**Features:**
- 🎯 **Smart Discovery**: Tries multiple naming patterns for unknown packages
- 📋 **Known Mappings**: Uses pre-defined mappings for popular packages  
- 🔧 **Custom Mappings**: Supports user-defined package mappings
- 🔍 **Intelligent Guessing**: Attempts various case combinations and naming patterns
- 📄 **JSON Parsing**: Uses `jq` for reliable JSON parsing (install with `brew install jq`)

**Requirements:**
- `jq` command-line JSON processor (recommended for best results)
- Falls back gracefully if `jq` is not available

```cmake
# Call this once in your main CMakeLists.txt
vcpkg_find_packages()
```

### vcpkg_add_package_mapping(package find_name target)

Adds a custom mapping for packages not in the known list.

```cmake
# Add custom mapping before calling vcpkg_find_packages()
vcpkg_add_package_mapping(my-special-lib MySpecialLib MySpecialLib::core)
vcpkg_find_packages()
```

### vcpkg_link_libraries(target visibility)

Links all found vcpkg packages to a target.

```cmake
# Link all packages to your target
vcpkg_link_libraries(my_target PRIVATE)
vcpkg_link_libraries(my_library PUBLIC)
```

### vcpkg_link_specific(target visibility packages...)

Links only specific packages to a target.

```cmake
# Link only fmt and spdlog
vcpkg_link_specific(my_target PRIVATE fmt spdlog)
```

### vcpkg_has_package(package result_var)

Checks if a package is available.

```cmake
vcpkg_has_package(fmt HAS_FMT)
if(HAS_FMT)
    # Use fmt-specific features
endif()
```

### vcpkg_list_packages()

Lists all available packages (useful for debugging).

```cmake
vcpkg_list_packages()  # Prints to console
```

## 🎯 Library Classes

### Calculator

Main calculator class providing mathematical operations.

#### Methods

- `add(T a, T b) -> T`: Adds two numbers
- `multiply(T a, T b) -> T`: Multiplies two numbers  
- `process_vector(const std::vector<T>&) -> std::vector<T>`: Processes vector

## 🔧 Utility Functions

- `sum_positive(const std::vector<T>&) -> T`: Sums positive numbers
- `filter_and_transform(const std::vector<T>&) -> std::vector<T>`: Filters and transforms

## 📝 Example Usage

### Basic CMakeLists.txt with vcpkg helpers

```cmake
cmake_minimum_required(VERSION 3.25)
project(MyProject)

# Include vcpkg helpers
include(cmake/VcpkgHelpers.cmake)

# Add custom mappings for packages not in known list (optional)
vcpkg_add_package_mapping(my-special-lib MySpecialLib MySpecialLib::core)

# Automatically find all packages from vcpkg.json
vcpkg_find_packages()

# Create your target
add_executable(my_app src/main.cpp)

# Link all vcpkg packages automatically
vcpkg_link_libraries(my_app PRIVATE)

# Or link specific packages only
# vcpkg_link_specific(my_app PRIVATE fmt spdlog)
```

### Advanced Usage

```cmake
# Add custom mappings for complex packages
vcpkg_add_package_mapping(weird-package-name WeirdPackage WeirdPackage::main)
vcpkg_add_package_mapping(legacy-lib LegacyLibrary legacy::lib)

# Find all packages (including custom ones)
vcpkg_find_packages()

# Check for optional packages
vcpkg_has_package(opencv HAS_OPENCV)
if(HAS_OPENCV)
    target_compile_definitions(my_app PRIVATE HAS_OPENCV)
    # OpenCV will be linked automatically by vcpkg_link_libraries
endif()

# List available packages for debugging
vcpkg_list_packages()
```

### How It Works

1. **JSON Parsing**: Uses `jq` for reliable parsing of `vcpkg.json`
   - Handles both string and object dependencies
   - Extracts package names and features correctly
   - Falls back gracefully if `jq` is not available

2. **Known Packages**: Uses pre-defined mappings for popular packages (fmt, spdlog, boost, etc.)

3. **Custom Mappings**: Uses your custom mappings added with `vcpkg_add_package_mapping()`

4. **Smart Discovery**: For unknown packages, tries multiple naming patterns:
   - Exact name: `my-package` -> `find_package(my-package)`
   - Title case: `my-package` -> `find_package(My-package)`
   - Upper case: `my-package` -> `find_package(MY-PACKAGE)`
   - With Config suffix: `my-package` -> `find_package(my-packageConfig)`

5. **Target Guessing**: Tries common target naming patterns:
   - `package::package`
   - `Package::Package`
   - `PACKAGE::PACKAGE`
   - And fallbacks...

6. **Complex Dependencies**: Supports vcpkg.json features like:
   ```json
   {
     "dependencies": [
       "fmt",
       {
         "name": "boost",
         "features": ["system", "filesystem"]
       }
     ]
   }
   ```
API_EOF
    
    log_success "Documentation created"
}

create_config_files() {
    log_header "Creating Configuration Files"
    
    # .gitignore
    cat > .gitignore << 'GITIGNORE_EOF'
# Build directories
build/
cmake-build-*/
out/

# vcpkg
vcpkg_installed/

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# OS files
.DS_Store
Thumbs.db

# Compiled binaries
*.exe
*.out
*.app
*.dSYM/

# Libraries
*.so
*.dylib
*.dll
*.a
*.lib

# Object files
*.o
*.obj
*.lo
*.slo

# CMake
CMakeCache.txt
CMakeFiles/
cmake_install.cmake
install_manifest.txt
CTestTestfile.cmake

# Testing
Testing/
*.gcda
*.gcno
*.gcov

# Package managers
conan.lock
graph_info.json
conanbuildinfo.*
conaninfo.txt
GITIGNORE_EOF
    
    # clang-format
    cat > .clang-format << 'CLANG_FORMAT_EOF'
---
Language: Cpp
BasedOnStyle: LLVM
IndentWidth: 4
ColumnLimit: 100
UseTab: Never
IndentCaseLabels: true
BreakBeforeBraces: Attach
AllowShortFunctionsOnASingleLine: Empty
AllowShortIfStatementsOnASingleLine: false
AllowShortLoopsOnASingleLine: false
AlwaysBreakTemplateDeclarations: Yes
BreakConstructorInitializers: BeforeColon
ConstructorInitializerIndentWidth: 4
ContinuationIndentWidth: 4
Cpp11BracedListStyle: true
PointerAlignment: Left
ReferenceAlignment: Left
SpaceAfterCStyleCast: false
SpaceAfterTemplateKeyword: false
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
Standard: c++20
CLANG_FORMAT_EOF
    
    # License
    cat > LICENSE << 'LICENSE_EOF'
MIT License

Copyright (c) 2024

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LICENSE_EOF
    
    log_success "Configuration files created"
}

show_completion() {
    log_header "Project Created Successfully!"
    
    echo -e "${GREEN}"
    cat << COMPLETION_EOF
🎉 Modern C++20 project '${PROJECT_NAME}' created!

📁 Project structure:
  ${PROJECT_NAME}/
  ├── src/                 # Source files
  ├── include/             # Headers
  ├── tests/               # Tests
  ├── scripts/             # Build scripts  
  ├── docs/                # Documentation
  └── .github/workflows/   # CI/CD

🚀 Next steps:
  cd ${PROJECT_NAME}
  
  # Quick build and run
  ./scripts/build.sh Release
  
  # Development workflow
  ./scripts/dev.sh build    # Debug build
  ./scripts/dev.sh test     # Run tests
  ./scripts/dev.sh format   # Format code

📚 Features included:
  ✅ Modern C++20 code examples
  ✅ CMake configuration with best practices
$(if [[ "$USE_VCPKG" == "true" ]]; then echo "  ✅ vcpkg with automatic package discovery"; fi)
$(if [[ "$USE_TESTING" == "true" ]]; then echo "  ✅ Catch2 testing framework"; fi)
  ✅ GitHub Actions CI/CD
  ✅ Code formatting and static analysis
  ✅ Comprehensive documentation

$(if [[ "$USE_VCPKG" == "true" ]]; then echo "📦 vcpkg Helper Functions:
  • vcpkg_find_packages()     - Auto-discover from vcpkg.json
  • vcpkg_link_libraries()    - Auto-link all packages
  • vcpkg_link_specific()     - Link specific packages
  • vcpkg_has_package()       - Check package availability
  • vcpkg_add_package_mapping() - Add custom mappings

🧠 Smart Discovery:
  • Known packages: Instant recognition
  • Unknown packages: Intelligent naming pattern matching
  • Custom mappings: For complex package names

"; fi)💡 Customize:
  - Edit CMakeLists.txt for build options
  - Modify vcpkg.json for dependencies
  - Add your code in src/ and include/
  - Write tests in tests/
$(if [[ "$USE_VCPKG" == "true" ]]; then echo "  - Use helper functions for easy package management"; fi)

Happy coding! 🎯
COMPLETION_EOF
    echo -e "${NC}"
}

main() {
    show_banner
    get_project_info
    
    log_info "Creating C++20 project: $PROJECT_NAME"
    log_info "Type: $PROJECT_TYPE | vcpkg: $USE_VCPKG | Testing: $USE_TESTING"
    echo
    
    create_project_structure
    create_cmake_files
    create_source_files
    create_test_files
    create_vcpkg_config
    create_build_scripts
    create_ci_config
    create_documentation
    create_config_files
    
    show_completion
}

main "$@"