# 🚀 Ultimate C++20 Development Environment

**The most complete and modern C++20 development setup for macOS and Linux.**

Stop wasting time configuring your C++ environment. Get productive in **minutes**, not hours.

## ✨ What This Does

🎯 **One-Command Setup**: Complete C++20 environment in under 5 minutes  
📦 **Modern Package Management**: vcpkg with npm-like experience  
🏗️ **Project Templates**: Console apps, libraries, and GUI applications  
🔧 **Development Tools**: CMake, Ninja, Clang with C++20 support  
🧪 **Testing Ready**: Catch2 integration and modern CMake patterns  
📚 **Best Practices**: Modern C++20 features and examples  

---

## 🚀 Quick Start

### **Complete Setup**
```bash
curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash
```

### **Create Your First Project**
```bash
# After setup, restart your terminal, then:
cpp-new my-awesome-project console

# Build and run
cd my-awesome-project
./scripts/build.sh
```

**That's it!** You now have a complete C++20 development environment.

---

## 📋 What Gets Installed

### **🔧 Development Environment**
- ✅ **CMake 3.25+**: Modern build system generator
- ✅ **Ninja**: Ultra-fast build system  
- ✅ **LLVM/Clang**: Latest C++20 compiler
- ✅ **GCC**: Alternative compiler
- ✅ **vcpkg**: Microsoft's C++ package manager
- ✅ **jq**: JSON processor for package management

### **🏗️ Project Creation Tool**
- ✅ **cpp-new command**: Create projects instantly
- ✅ **Modern Templates**: Console, library, GUI projects
- ✅ **CMake Best Practices**: Target-based configuration
- ✅ **vcpkg Integration**: Automatic package discovery
- ✅ **Testing Framework**: Catch2 setup included

### **📦 Package Management Helper**
- ✅ **vcpkg-helper**: npm-like package management
- ✅ **Smart Commands**: add, remove, list, search packages
- ✅ **Auto vcpkg.json**: Automatic manifest management
- ✅ **Convenient Aliases**: vcpkg-add, vcpkg-list shortcuts

---

## 🔄 Installation Options

### **Interactive Wizard (Recommended)**
```bash
curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash
```

The wizard guides you through:
1. **Environment Setup**: Essential tools and compilers
2. **Project Creator**: cpp-new command setup
3. **Package Helper**: vcpkg-helper tools

### **Automated Options**
```bash
# Complete setup (all components)
curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash -s -- --all

# Environment only
curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash -s -- --env-only

# Tools only (project creator + package helper)
curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash -s -- --tools-only
```

---

## 🎯 Usage Examples

### **Project Creation**

#### **Console Application**
```bash
cpp-new calculator console
cd calculator
./scripts/build.sh
```

#### **Static Library**
```bash
cpp-new mathlib library
cd mathlib
./scripts/build.sh
./build/mathlib_example  # Run example
```

#### **GUI Application**
```bash
cpp-new myapp gui
cd myapp
vcpkg-add imgui
./scripts/build.sh
```

### **Package Management**

#### **Basic Commands**
```bash
# Add packages (npm-like experience)
vcpkg-add fmt              # Fast formatting
vcpkg-add spdlog           # Logging library  
vcpkg-add nlohmann-json    # JSON library
vcpkg-add catch2           # Testing framework

# List packages
vcpkg-list

# Search packages
vcpkg-search http

# Remove packages
vcpkg-remove fmt
```

#### **Advanced Package Management**
```bash
# Add packages with features
vcpkg-helper add "boost[system,filesystem]"
vcpkg-helper add "opencv[contrib]"

# Get package information
vcpkg-helper info fmt

# Update all packages
vcpkg-helper update
```

### **Development Workflow**

```bash
# Project development cycle
cd my-project
./scripts/dev.sh build     # Debug build
./scripts/dev.sh test      # Run tests  
./scripts/dev.sh format    # Format code
./scripts/dev.sh analyze   # Static analysis
./scripts/dev.sh clean     # Clean build
```

---

## 🔧 Advanced Features

### **Modern C++20 Examples**

Every generated project includes real C++20 code:

```cpp
// 🔥 Concepts for type safety
template<typename T>
concept Numeric = std::integral<T> || std::floating_point<T>;

template<Numeric T>
constexpr T square(T value) noexcept {
    return value * value;
}

// 🌊 Ranges for functional programming  
auto process_data(const std::vector<int>& numbers) {
    return numbers 
        | std::views::filter([](int n) { return n > 0; })
        | std::views::transform(square<int>)
        | std::views::take(10);
}

// 🎯 Designated initializers for clarity
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
```

### **Smart vcpkg Integration**

Generated projects use intelligent vcpkg helper functions:

```cmake
# CMakeLists.txt with automatic package discovery
include(cmake/VcpkgHelpers.cmake)

# Automatically finds all packages from vcpkg.json
vcpkg_find_packages()

# Links all packages automatically
vcpkg_link_libraries(my_target PRIVATE)

# Or link specific packages
vcpkg_link_specific(my_target PRIVATE fmt spdlog)
```

### **Automatic Package Discovery**

The vcpkg helpers intelligently discover packages:

1. **Known Packages**: Uses pre-defined mappings for popular packages
2. **Custom Mappings**: Supports user-defined package mappings  
3. **Smart Discovery**: Tries multiple naming patterns for unknown packages
4. **Target Guessing**: Attempts various target naming conventions

---

## 🎨 Project Structure

Generated projects follow modern C++ best practices:

```
my-project/
├── src/                    # Source files
├── include/my-project/     # Header files
├── tests/                  # Test files
├── scripts/                # Build scripts
├── cmake/                  # CMake modules
│   ├── VcpkgHelpers.cmake # Smart package discovery
│   ├── CompilerWarnings.cmake
│   └── StaticAnalysis.cmake
├── docs/                   # Documentation
├── .github/workflows/      # CI/CD
├── CMakeLists.txt         # Modern CMake config
├── vcpkg.json             # Package manifest
├── .clang-format          # Code formatting
└── .gitignore             # Git configuration
```

### **CMake Best Practices**

```cmake
# Modern CMake 3.25+
cmake_minimum_required(VERSION 3.25)

# C++20 enforcement
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Smart package discovery
include(cmake/VcpkgHelpers.cmake)
vcpkg_find_packages()

# Modern target-based approach
add_executable(my_app src/main.cpp)
vcpkg_link_libraries(my_app PRIVATE)
```

### **Testing Integration**

```cpp
// Catch2 v3 tests included
TEST_CASE("Math operations", "[math]") {
    REQUIRE(square(4) == 16);
    REQUIRE(add(2, 3) == 5);
}

// C++20 concepts testing
TEST_CASE("Concepts work", "[concepts]") {
    REQUIRE(square(2) == 4);      // int
    REQUIRE(square(2.5) == 6.25); // double
}
```

---

## 📚 Available Commands

### **Project Creation**
```bash
cpp-new <name> [type]        # Create new C++20 project
  Types: console, library, gui
```

### **Package Management**
```bash
vcpkg-helper <command>       # Full package management
vcpkg-add <package>          # Add package (shortcut)
vcpkg-remove <package>       # Remove package (shortcut)
vcpkg-list                   # List packages (shortcut)
vcpkg-search <query>         # Search packages (shortcut)
```

### **Project Scripts**
```bash
./scripts/build.sh [type]    # Build project (Debug/Release)
./scripts/dev.sh <command>   # Development workflow
  Commands: build, test, format, analyze, clean
```

---

## 🆘 Troubleshooting

### **Common Issues**

#### **"vcpkg not found" or Package Issues**
```bash
# Check VCPKG_ROOT environment variable
echo $VCPKG_ROOT

# If empty, restart terminal or run:
source ~/.zshrc

# Run diagnostic tool for detailed analysis
curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/helpers/vcpkg-diagnose.sh | bash
```

#### **"cpp-new command not found"**
```bash
# Restart terminal or reload shell
source ~/.zshrc

# Or run the installer again
curl -fsSL https://raw.githubusercontent.com/danielsalles/setup_cpp20/main/install.sh | bash -s -- --tools-only
```

#### **"CMake version too old"**
```bash
# Update CMake via Homebrew
brew upgrade cmake

# Check version
cmake --version  # Should be 3.25+
```

#### **"C++20 not supported"**
```bash
# Update compiler
brew install llvm

# Check C++20 support
clang++ -std=c++20 --version
```

### **Getting Help**

1. **Check Issues**: [GitHub Issues](https://github.com/danielsalles/setup_cpp20/issues)
2. **Discussion**: [GitHub Discussions](https://github.com/danielsalles/setup_cpp20/discussions)  
3. **Documentation**: [Project Wiki](https://github.com/danielsalles/setup_cpp20/wiki)

### **Recent Improvements**

**v2.0.1 - vcpkg Installation Fixes**
- ✅ **Fixed git repository errors**: No more "fatal: not a git repository" errors
- ✅ **Improved vcpkg detection**: Better handling of existing vcpkg installations
- ✅ **Simplified update logic**: Focus on installation rather than updates to avoid conflicts
- ✅ **Enhanced error handling**: Graceful fallbacks when git operations fail

### **Report Bugs**

Include this information:
- 🖥️ **System**: `uname -a`
- 🍎 **macOS Version**: `sw_vers -productVersion` (if macOS)
- 🔧 **Tool Versions**: `cmake --version`, `clang++ --version`
- 📋 **Error Output**: Full error messages

---

## 📊 Features Comparison

| Feature | This Setup | Manual Setup | Other Tools |
|---------|------------|--------------|-------------|
| **Setup Time** | 5 minutes | Hours | Varies |
| **C++20 Support** | ✅ Full | ⚠️ Manual | ⚠️ Limited |
| **Package Management** | ✅ npm-like | ❌ Manual | ⚠️ Basic |
| **Project Templates** | ✅ Modern | ❌ None | ⚠️ Basic |
| **Smart Discovery** | ✅ Automatic | ❌ Manual | ❌ None |
| **Best Practices** | ✅ Built-in | ⚠️ Manual | ⚠️ Varies |
| **Testing Ready** | ✅ Included | ❌ Manual | ⚠️ Basic |
| **CI/CD Templates** | ✅ GitHub Actions | ❌ None | ⚠️ Limited |

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### **Why MIT?**
- ✅ **Commercial Use**: Use in commercial projects
- ✅ **Modification**: Adapt to your needs
- ✅ **Distribution**: Share with your team
- ✅ **Private Use**: No restrictions

---

## 🙏 Acknowledgments

### **Inspiration**
- 🦀 **Rust's Cargo**: Package management inspiration
- 📦 **Node.js npm**: Developer experience model
- 🐍 **Python pip**: Simplicity goals

### **Technology Stack**
- 🏗️ **CMake**: Build system foundation
- 📦 **vcpkg**: Microsoft's excellent package manager
- 🍺 **Homebrew**: macOS package management
- 🔧 **LLVM/Clang**: Modern C++20 compiler

### **Community**
Thanks to all contributors, testers, and users who make this project better every day!

---

**Made with ❤️ by developers, for developers**

*Stop configuring. Start coding.* 🚀
