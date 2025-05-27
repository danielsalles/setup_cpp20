# C++20 Modern Development Environment Setup for macOS

This script automatically configures a complete modern C++20 development environment on macOS with essential tools, package managers, and convenient aliases.

## 🚀 What This Setup Does

### 1. **Package Manager Installation**
- Installs **Homebrew** (if not already present) - the essential package manager for macOS

### 2. **Development Tools Installation**
- **CMake**: Cross-platform build system generator
- **Ninja**: Fast build system
- **pkg-config**: Tool for managing compilation flags and library dependencies
- **LLVM**: Modern Clang compiler with C++20 support
- **GCC**: GNU Compiler Collection as alternative

### 3. **Convenient Aliases Configuration**
Adds useful aliases to your `~/.zshrc`:
- `cpp20`: Basic C++20 compilation with Clang
- `cpp20-debug`: Debug build with warnings enabled
- `cpp20-release`: Optimized release build
- `cpprun()`: Function to quickly compile and run C++ files

### 4. **Package Managers Setup**
- **vcpkg**: Microsoft's C++ package manager
  - Clones official repository to `~/vcpkg`
  - Configures IDE integration
- **Conan**: Popular C++ package manager
  - Installs via pip3
  - Auto-detects system profile

## 📋 Prerequisites

- macOS (any recent version)
- Internet connection
- Terminal access
- Python 3 (usually pre-installed on macOS)

## 🔧 How to Execute

### Option 1: Direct Execution
```bash
# Make the script executable
chmod +x install_cpp20_macOS.sh

# Run the script
./install_cpp20_macOS.sh
```

### Option 2: Download and Run
```bash
# If downloading from a repository
curl -O https://your-repo/install_cpp20_macOS.sh
chmod +x install_cpp20_macOS.sh
./install_cpp20_macOS.sh
```

### Option 3: Run with Bash
```bash
bash install_cpp20_macOS.sh
```

## ⚡ Quick Start After Installation

1. **Restart your terminal** or run:
   ```bash
   source ~/.zshrc
   ```

2. **Test your installation**:
   ```bash
   cpp20 --version
   cmake --version
   conan --version
   ```

3. **Quick compile and run example**:
   ```bash
   # Create a simple C++20 file
   echo '#include <iostream>
   int main() {
       std::cout << "Hello C++20!" << std::endl;
       return 0;
   }' > hello.cpp
   
   # Compile and run
   cpprun hello.cpp
   ```

## 🛠️ Available Commands After Setup

| Command | Description |
|---------|-------------|
| `cpp20 file.cpp` | Basic C++20 compilation |
| `cpp20-debug file.cpp` | Debug build with warnings |
| `cpp20-release file.cpp` | Optimized release build |
| `cpprun file.cpp` | Compile and run immediately |

## 📚 Package Management

### Using vcpkg
```bash
cd ~/vcpkg
./vcpkg search [package-name]
./vcpkg install [package-name]

# For CMake integration
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=~/vcpkg/scripts/buildsystems/vcpkg.cmake
```

### Using Conan
```bash
conan search [package-name]
conan install [package-name]

# For CMake integration
conan install . --build=missing
cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=build/conan_toolchain.cmake
```

## 🏗️ Modern CMakeLists.txt Template

This repository includes a modern `CMakeLists.txt` template that demonstrates:

### ✨ Modern Features
- **C++20 Standard**: Enforced with no extensions
- **Cross-platform**: macOS, Linux, and Windows support
- **Package Manager Integration**: Ready for vcpkg and Conan
- **Security Hardening**: Stack protection and fortification
- **IDE Support**: Export compile commands for better IDE integration
- **Build System Optimization**: Ninja build system detection

### 🎯 Key Highlights
- Uses target-based modern CMake (3.25+)
- Compiler-specific optimizations for Clang, GCC, and MSVC
- Matches the aliases created by our setup script
- Security flags for production builds
- Comprehensive warning flags for better code quality

### 🔧 How to Use the CMakeLists.txt Template

#### For a New Project:
1. **Copy the template**:
   ```bash
   cp CMakeLists.txt /path/to/your/new/project/
   ```

2. **Customize for your project**:
   ```cmake
   # Change project name and details
   project(YourProjectName
       VERSION 1.0.0
       DESCRIPTION "Your project description"
       LANGUAGES CXX
   )
   
   # Update executable name and source files
   add_executable(${PROJECT_NAME} 
       src/main.cpp
       src/other_file.cpp
   )
   ```

3. **Build your project**:
   ```bash
   mkdir build && cd build
   cmake -G Ninja ..
   ninja
   ```

#### For Library Projects:
```cmake
# Instead of add_executable, use:
add_library(${PROJECT_NAME} 
    src/library.cpp
    include/library.hpp
)

# Add include directories
target_include_directories(${PROJECT_NAME} 
    PUBLIC include
    PRIVATE src
)
```

#### Adding Dependencies:
```cmake
# vcpkg example
find_package(fmt CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE fmt::fmt)

# Conan example (after conan install)
find_package(Boost REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE Boost::Boost)
```

## 🔒 Security Notes

- ✅ Uses official sources (Homebrew, Microsoft vcpkg, Conan PyPI)
- ✅ No elevated privileges required
- ✅ Only appends to `~/.zshrc` (doesn't overwrite)
- ✅ Checks for existing installations before proceeding

## 🎯 Perfect For

- Modern C++20 development
- Cross-platform C++ projects
- Learning C++20 features
- Professional C++ development
- Open source C++ contributions

## 📝 What Gets Modified

- Installs packages via Homebrew
- Adds aliases to `~/.zshrc`
- Creates `~/vcpkg` directory
- Installs Conan via pip3

## 🆘 Troubleshooting

If you encounter issues:

1. **Homebrew installation fails**: Check your internet connection and try again
2. **Permission errors**: Ensure you're not running as root
3. **Aliases not working**: Run `source ~/.zshrc` or restart terminal
4. **vcpkg issues**: Check if Git is installed (`brew install git`)

## 🔄 Uninstalling

To remove components installed by this script:
```bash
# Remove Homebrew packages
brew uninstall cmake ninja pkg-config llvm gcc

# Remove vcpkg
rm -rf ~/vcpkg

# Remove Conan
pip3 uninstall conan

# Remove aliases (manually edit ~/.zshrc)
```

## 🔨 Smart Build Script

This repository includes a powerful `build.sh` script that simplifies the build process:

### ✨ Features
- **Intelligent Defaults**: Auto-detects CPU cores, uses Clang by default
- **Package Manager Integration**: Built-in support for vcpkg and Conan
- **Error Handling**: Strict error checking with helpful messages
- **Cross-Platform**: Works on macOS, Linux, and Windows (with WSL)
- **Flexible Options**: Multiple build types, compilers, and configurations

### 🚀 Quick Usage
```bash
# Make executable (first time only)
chmod +x build.sh

# Quick release build
./build.sh

# Debug build and run
./build.sh -t Debug -r

# Clean build with vcpkg
./build.sh --clean --vcpkg

# Verbose build with Conan using 8 jobs
./build.sh --conan -v -j 8
```

### 📋 Available Options
| Option | Description | Default |
|--------|-------------|---------|
| `-t, --type` | Build type (Debug, Release, RelWithDebInfo) | Release |
| `-c, --compiler` | Compiler (clang++, g++) | clang++ |
| `--clean` | Clean build directory first | false |
| `-r, --run` | Run executable after building | false |
| `-v, --verbose` | Verbose build output | false |
| `--vcpkg` | Use vcpkg for dependencies | false |
| `--conan` | Use Conan for dependencies | false |
| `-j, --jobs` | Number of parallel jobs | auto-detected |

### 🛡️ Safety Features
- **Dependency Checks**: Verifies all required tools are installed
- **Error Handling**: Stops on first error with clear messages
- **Input Validation**: Validates build types and options
- **Tool Detection**: Checks for CMake, Ninja, and compilers

## 📁 Repository Structure

This repository serves as a **reference and template** for modern C++20 development:

```
setup-c++20/
├── install_cpp20_macOS.sh    # Setup script for macOS
├── build.sh                  # Smart build script
├── CMakeLists.txt            # Modern CMake template
├── modern_cpp20_demo.cpp     # C++20 features demonstration
└── README.md                 # This documentation
```

### 🎯 Purpose of Each File

- **`install_cpp20_macOS.sh`**: Complete environment setup script
- **`build.sh`**: Smart build script with package manager integration
- **`CMakeLists.txt`**: Production-ready CMake template with modern practices
- **`modern_cpp20_demo.cpp`**: Demonstration of C++20 features (Concepts, Ranges, Format)
- **`README.md`**: Comprehensive documentation and usage guide

### 🎮 Try the Demo

The included `modern_cpp20_demo.cpp` showcases modern C++20 features:

- **Concepts**: Type constraints for template parameters
- **Ranges**: Functional programming with views and transformations
- **Format Library**: Modern string formatting (when available)
- **Platform Detection**: CMake-based conditional compilation

```bash
# Build and run the demo
./build.sh -r

# Expected output shows C++20 features in action
```

### 💡 How to Use This Repository

1. **For Environment Setup**: Run the installation script
2. **For New Projects**: Copy and customize the CMakeLists.txt
3. **For Reference**: Use this README as a quick reference guide
4. **For Learning**: Study the modern CMake practices implemented

---

**Ready to start your modern C++20 journey!** 🚀 