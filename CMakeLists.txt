cmake_minimum_required(VERSION 3.25)

# 🎯 Project setup with modern standards
project(ModernCpp20Demo
    VERSION 1.0.0
    DESCRIPTION "C++20 Modern Features Demonstration"
    LANGUAGES CXX
)

# 🚀 Force C++20 - No compromise!
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 📦 Package managers integration
# vcpkg integration (if using vcpkg)
if(DEFINED CMAKE_TOOLCHAIN_FILE)
    message(STATUS "📦 Using vcpkg toolchain: ${CMAKE_TOOLCHAIN_FILE}")
endif()

# Conan integration (if using conan)
if(EXISTS "${CMAKE_BINARY_DIR}/conan_toolchain.cmake")
    include("${CMAKE_BINARY_DIR}/conan_toolchain.cmake")
    message(STATUS "🐍 Using Conan toolchain")
endif()

# 🔧 Compiler-specific optimizations
if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    # Clang specific flags (matches our setup aliases)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")
    set(COMPILER_WARNINGS
        -Wall -Wextra -Wpedantic
        -Wunused -Wformat=2
        -Wnull-dereference
        -Wdouble-promotion
        -Wshadow
        -Wconversion
    )
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    # GCC specific flags
    set(COMPILER_WARNINGS
        -Wall -Wextra -Wpedantic
        -Wunused -Wformat=2
        -Wnull-dereference
        -Wdouble-promotion
        -Wduplicated-cond
        -Wlogical-op
        -Wshadow
        -Wconversion
    )
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    # MSVC specific flags
    set(COMPILER_WARNINGS
        /W4
        /permissive-
        /w14640 # Enable warning on thread un-safe static member initialization
    )
endif()

# 🎨 Build types configuration
set(CMAKE_CXX_FLAGS_DEBUG "-g -O0 -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG -march=native")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "-O2 -g -DNDEBUG")

# 🏗 Create executable target
add_executable(${PROJECT_NAME} modern_cpp20_demo.cpp)

# 🎯 Apply modern CMake practices
target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_20)
target_compile_options(${PROJECT_NAME} PRIVATE ${COMPILER_WARNINGS})

# 🔒 Security hardening flags
if(APPLE)
    # macOS security flags
    target_compile_options(${PROJECT_NAME} PRIVATE
        -fstack-protector-strong
        -D_FORTIFY_SOURCE=2
    )
    target_link_options(${PROJECT_NAME} PRIVATE
        -Wl,-dead_strip
    )
elseif(UNIX)
    # Linux security flags
    target_compile_options(${PROJECT_NAME} PRIVATE
        -fstack-protector-strong
        -D_FORTIFY_SOURCE=2
    )
    target_link_options(${PROJECT_NAME} PRIVATE
        -Wl,-z,relro
        -Wl,-z,now
    )
endif()

# 🍎 macOS specific settings
if(APPLE)
    target_compile_definitions(${PROJECT_NAME} PRIVATE APPLE_PLATFORM)
    # Use the LLVM installed by our setup
    if(EXISTS "/opt/homebrew/opt/llvm/bin/clang++")
        message(STATUS "🍎 Using Homebrew LLVM")
    endif()
endif()

# 🪟 Windows specific settings
if(WIN32)
    target_compile_definitions(${PROJECT_NAME} PRIVATE WIN32_PLATFORM)
    # Windows-specific libraries
    # target_link_libraries(${PROJECT_NAME} PRIVATE ws2_32)
endif()

# 🐧 Linux specific settings
if(UNIX AND NOT APPLE)
    target_compile_definitions(${PROJECT_NAME} PRIVATE LINUX_PLATFORM)
endif()

# 📊 Print build information
message(STATUS "🚀 Build Configuration:")
message(STATUS "  📁 Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  🔧 Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "  📋 C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  🎯 Target: ${PROJECT_NAME}")
message(STATUS "  🛠 Generator: ${CMAKE_GENERATOR}")

# 🧪 Enable testing (optional)
option(ENABLE_TESTING "Enable testing" OFF)
if(ENABLE_TESTING)
    enable_testing()
    # Example: add_subdirectory(tests)
endif()

# 📦 Install configuration (optional)
install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION bin
    COMPONENT Runtime
)

# 🎨 IDE support
set_property(GLOBAL PROPERTY USE_FOLDERS ON)
if(CMAKE_GENERATOR STREQUAL "Ninja")
    message(STATUS "🥷 Using Ninja build system (fast builds!)")
endif()

# 📝 Export compile commands for IDEs
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)