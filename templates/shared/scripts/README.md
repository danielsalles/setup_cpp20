# Development Scripts Workflow

Welcome to the **{{ project_name }}** development scripts ecosystem! This directory contains a comprehensive collection of scripts designed to streamline your C++20 development workflow, from building and testing to deployment and maintenance.

## 📋 Quick Start

```bash
# Build your project
./build.sh --release

# Run tests with coverage
./test.sh --coverage --html

# Format your code
./format.sh --check

# Run static analysis
./analyze.sh --fix

# Clean build artifacts
./clean.sh --all
```

## 🗂️ Script Categories

### 🏗️ Core Development Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| [`build.sh`](#build-script) | Project compilation and build management | `templates/shared/scripts/` |
| [`test.sh`](#test-script) | Test execution with coverage and reporting | `templates/shared/scripts/` |
| [`format.sh`](#format-script) | Code formatting with clang-format | `templates/shared/scripts/` |
| [`analyze.sh`](#analyze-script) | Static analysis with clang-tidy | `templates/shared/scripts/` |

### 🛠️ Maintenance Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| [`clean.sh`](#clean-script) | Build artifacts and temporary file cleanup | `templates/shared/scripts/` |
| [`cache-clear.sh`](#cache-clear-script) | CMake and vcpkg cache management | `templates/shared/scripts/` |
| [`deps-update.sh`](#deps-update-script) | Dependency management and updates | `templates/shared/scripts/` |
| [`sanitize.sh`](#sanitize-script) | Runtime sanitizer analysis | `templates/shared/scripts/` |
| [`version-bump.sh`](#version-bump-script) | Project version management | `templates/shared/scripts/` |

### 🚀 CI/CD Integration Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| [`ci-build.sh`](#ci-build-script) | CI/CD optimized build process | `templates/shared/scripts/ci/` |
| [`ci-validate.sh`](#ci-validate-script) | Pre-merge validation suite | `templates/shared/scripts/ci/` |
| [`ci-package.sh`](#ci-package-script) | Package creation for distribution | `templates/shared/scripts/ci/` |
| [`ci-deploy.sh`](#ci-deploy-script) | Deployment automation | `templates/shared/scripts/ci/` |
| [`ci-docs.sh`](#ci-docs-script) | Documentation generation | `templates/shared/scripts/ci/` |

### 🔧 Utility Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| [`platform_compat.sh`](#platform-compat) | Cross-platform compatibility layer | `templates/shared/scripts/utils/` |
| [`migrate_to_compat.sh`](#migrate-script) | Migration tool for compatibility | `templates/shared/scripts/utils/` |
| [`generate_docs.sh.template`](#generate-docs) | Documentation generation template | `templates/shared/scripts/` |

For detailed documentation of each script, see the [Complete Script Reference](#complete-script-reference) below.

## 🏗️ Development Workflows

### Standard Development Workflow

```bash
# 1. Set up development environment
./cache-clear.sh --reconfigure
./deps-update.sh

# 2. Development cycle
./format.sh --git-changed --in-place
./build.sh --debug --sanitizer address
./test.sh --coverage

# 3. Pre-commit validation
./format.sh --check
./analyze.sh --checks modernize-*,readability-*
./test.sh --fail-fast

# 4. Release preparation
./clean.sh --all
./build.sh --release
./test.sh --xml --html
./ci-package.sh
```

### CI/CD Workflow

```bash
# 1. Validation phase
./ci-validate.sh

# 2. Build matrix
./ci-build.sh --matrix-build

# 3. Package creation
./ci-package.sh --all

# 4. Deployment
./ci-deploy.sh --environment staging
```

## 🎯 Quick Reference

### Build & Test

```bash
# Development build with checks
./build.sh --debug --sanitizer address --coverage
./test.sh --coverage --html

# Production build
./build.sh --release --compiler clang++ --ccache
./test.sh --xml
```

### Code Quality

```bash
# Format and analyze
./format.sh --git-changed --in-place
./analyze.sh --fix --checks modernize-*

# Comprehensive validation
./ci-validate.sh
```

### Maintenance

```bash
# Clean project
./clean.sh --all
./cache-clear.sh

# Update dependencies
./deps-update.sh --upgrade
```

## 🐛 Troubleshooting

### Common Issues

**Build failures with vcpkg:**
```bash
./cache-clear.sh --vcpkg
./deps-update.sh --update-vcpkg --bootstrap
```

**Formatting conflicts:**
```bash
./format.sh --create-config --style Google
```

**Test failures:**
```bash
./sanitize.sh --asan --verbose
./test.sh --framework catch2 --verbose
```

## 📖 Complete Script Reference

### Build Script (`build.sh`)

Advanced build management with extensive configuration options.

```bash
# Basic usage
./build.sh                    # Default debug build
./build.sh --release         # Release build

# Advanced options
./build.sh --compiler clang++ --ccache --jobs 8
./build.sh --cmake-args "-DENABLE_TESTING=ON"
./build.sh --sanitizer address --coverage
```

**Key Features:**
- Compiler selection (GCC, Clang, MSVC)
- Build types (Debug, Release, RelWithDebInfo, MinSizeRel)
- Performance optimization (ccache, parallel builds)
- Analysis integration (sanitizers, static analysis)
- Cross-platform support

### Test Script (`test.sh`)

Comprehensive test execution with reporting and coverage.

```bash
# Basic testing
./test.sh                     # Run all tests
./test.sh --coverage         # Generate coverage reports

# Advanced testing
./test.sh --framework catch2 --shuffle --timeout 30
./test.sh --xml --html --gcovr
```

**Key Features:**
- Framework support (Catch2, Google Test, CTest)
- Report generation (XML, JSON, HTML)
- Coverage analysis (lcov, gcovr)
- Test management (filtering, shuffling, timeouts)

### Format Script (`format.sh`)

Code formatting with clang-format integration.

```bash
# Check formatting
./format.sh --check

# Format files
./format.sh --git-changed --in-place
./format.sh --create-config --style Google
```

**Key Features:**
- Style presets (Google, LLVM, Chromium, Mozilla, WebKit)
- Git integration (format changed files only)
- Pre-commit hook support
- Configuration management

### Analyze Script (`analyze.sh`)

Static analysis with clang-tidy.

```bash
# Basic analysis
./analyze.sh                  # Analyze all files
./analyze.sh --fix           # Apply fixes

# Advanced analysis
./analyze.sh --checks modernize-*,readability-*
./analyze.sh --format json --output report.json
```

**Key Features:**
- Check categories (modernize, readability, performance)
- Output formats (text, HTML, JSON)
- Automatic fixes
- Incremental analysis

### Clean Script (`clean.sh`)

Project cleanup and maintenance.

```bash
# Basic cleanup
./clean.sh                   # Clean build artifacts
./clean.sh --all            # Deep clean

# Targeted cleanup
./clean.sh --category build,temp,cmake
./clean.sh --dry-run --preserve-ide
```

**Cleanup Categories:**
- build: Build directories and object files
- temp: Temporary files
- cmake: CMake cache and generated files
- vcpkg: vcpkg build artifacts
- ide: IDE-generated files
- test: Test outputs and coverage data

### Cache Clear Script (`cache-clear.sh`)

Cache management and project reset.

```bash
# Clear all caches
./cache-clear.sh

# Targeted clearing
./cache-clear.sh --cmake --vcpkg --compiler
./cache-clear.sh --reconfigure --build-type Release
```

### Dependencies Update Script (`deps-update.sh`)

Dependency management with vcpkg.

```bash
# Update all dependencies
./deps-update.sh

# Specific updates
./deps-update.sh --packages fmt,spdlog --upgrade
./deps-update.sh --update-vcpkg --bootstrap
```

### Sanitize Script (`sanitize.sh`)

Runtime analysis with sanitizers.

```bash
# Run all sanitizers
./sanitize.sh

# Specific sanitizer
./sanitize.sh --sanitizer address
./sanitize.sh --asan --verbose
```

**Supported Sanitizers:**
- AddressSanitizer (ASan): Memory errors
- UndefinedBehaviorSanitizer (UBSan): Undefined behavior
- ThreadSanitizer (TSan): Race conditions
- MemorySanitizer (MSan): Uninitialized memory

### Version Bump Script (`version-bump.sh`)

Project version management.

```bash
# Semantic versioning
./version-bump.sh patch      # 1.2.3 -> 1.2.4
./version-bump.sh minor      # 1.2.3 -> 1.3.0
./version-bump.sh major      # 1.2.3 -> 2.0.0

# Advanced versioning
./version-bump.sh --version 2.1.0 --changelog --tag
```

### CI/CD Scripts

**CI Build (`ci-build.sh`):**
```bash
./ci-build.sh --preset ci-linux
./ci-build.sh --matrix-build --upload-artifacts
```

**CI Validation (`ci-validate.sh`):**
```bash
./ci-validate.sh
./ci-validate.sh --skip-tests --format-check
```

**CI Package (`ci-package.sh`):**
```bash
./ci-package.sh
./ci-package.sh --deb --rpm --appimage
```

### Platform Compatibility (`platform_compat.sh`)

Cross-platform compatibility layer.

```bash
# Source the library
source "utils/platform_compat.sh"

# Use compatible functions
OS_TYPE=$(detect_os_type)
CPU_CORES=$(get_cpu_cores)
```

**Supported Platforms:**
- Linux (all major distributions)
- macOS (Intel and Apple Silicon)
- Windows (WSL, MSYS2, Cygwin)
- FreeBSD

## 🤝 Contributing

### Adding New Scripts

1. Follow existing naming conventions
2. Include comprehensive help documentation
3. Add cross-platform compatibility
4. Integrate with template system
5. Update documentation

### Script Structure Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source compatibility layer
source "$(dirname "$0")/utils/platform_compat.sh" 2>/dev/null || true

# Configuration
SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"

# Help function
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [options]
Description: Brief description

Options:
    -h, --help          Show help
    -v, --version       Show version
EOF
}

# Main implementation
main() {
    # Implementation here
}

main "$@"
```

## 📋 Dependencies Graph

```
build.sh ←─── ci-build.sh
    │
    └─── test.sh ←─── ci-validate.sh
              │
              └─── sanitize.sh

format.sh ←─── ci-validate.sh
analyze.sh ←─── ci-validate.sh

clean.sh
cache-clear.sh ←─── deps-update.sh
deps-update.sh
version-bump.sh ←─── ci-package.sh

platform_compat.sh ←─── (all scripts)
```

---

For detailed help on any script, run `script.sh --help`. 