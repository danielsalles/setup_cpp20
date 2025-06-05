# Contributing to {{ project_name }} Development Scripts

Thank you for your interest in contributing to the {{ project_name }} development scripts ecosystem! This guide will help you understand how to contribute effectively.

## 📋 Table of Contents

- [Getting Started](#getting-started)
- [Script Standards](#script-standards)
- [Development Workflow](#development-workflow)
- [Testing Guidelines](#testing-guidelines)
- [Documentation Requirements](#documentation-requirements)
- [Submission Process](#submission-process)

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Bash 3.0+** (for compatibility)
- **Git** for version control
- **Basic understanding** of shell scripting
- **Familiarity** with the project's existing scripts

### Setting Up Development Environment

```bash
# 1. Fork and clone the repository
git clone <your-fork-url>
cd setup_cpp20

# 2. Familiarize yourself with existing scripts
ls -la templates/shared/scripts/
./templates/shared/scripts/build.sh --help

# 3. Test the cross-platform compatibility layer
source templates/shared/scripts/utils/platform_compat.sh
echo "OS: $(detect_os_type)"
```

## 📝 Script Standards

### Naming Conventions

- **Core scripts**: Use descriptive verbs (`build.sh`, `test.sh`, `format.sh`)
- **Maintenance scripts**: Use action-object pattern (`deps-update.sh`, `cache-clear.sh`)
- **CI scripts**: Prefix with `ci-` (`ci-build.sh`, `ci-validate.sh`)
- **Utility scripts**: Descriptive names (`platform_compat.sh`, `migrate_to_compat.sh`)

### Script Structure Template

Every new script should follow this structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source compatibility layer
source "$(dirname "$0")/utils/platform_compat.sh" 2>/dev/null || {
    # Fallback implementations for core functions
    log_info() { echo "ℹ️  $*"; }
    log_success() { echo "✅ $*"; }
    log_warning() { echo "⚠️  $*"; }
    log_error() { echo "❌ $*" >&2; }
}

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Configuration variables
DEFAULT_OPTION="value"
ENABLE_FEATURE=false

# Help function (REQUIRED)
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [options]

Brief description of what this script does.

Options:
    -h, --help              Show this help message
    -v, --version           Show version information
    --option VALUE          Description of this option
    --enable-feature        Enable specific feature
    
    Output Options:
    --quiet                 Suppress non-essential output
    --verbose               Show detailed output
    --dry-run               Show what would be done without executing

Examples:
    $SCRIPT_NAME --option value
    $SCRIPT_NAME --enable-feature --verbose

Dependencies:
    - tool1: Purpose of tool1
    - tool2: Purpose of tool2

EOF
}

# Version function (REQUIRED)
show_version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
}

# Main implementation
main() {
    # Argument parsing
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            --option)
                DEFAULT_OPTION="$2"
                shift 2
                ;;
            --enable-feature)
                ENABLE_FEATURE=true
                shift
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Main logic here
    log_info "Starting script execution..."
    
    # Implementation...
    
    log_success "Script completed successfully!"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Required Features

Every script must include:

1. **Help documentation** (`--help` flag)
2. **Version information** (`--version` flag)
3. **Error handling** (`set -euo pipefail`)
4. **Logging functions** (info, success, warning, error)
5. **Cross-platform compatibility** (use compatibility layer)
6. **Template variable support** (`{{ project_name }}` placeholders)

### Optional but Recommended Features

- **Dry-run mode** (`--dry-run` flag)
- **Verbose mode** (`--verbose` flag)
- **Quiet mode** (`--quiet` flag)
- **Configuration file support**
- **Progress indicators** for long-running operations

## 🔧 Development Workflow

### 1. Planning Phase

Before writing code:

1. **Check existing scripts** - Avoid duplication
2. **Review compatibility requirements** - Cross-platform support
3. **Plan integration points** - How it fits with other scripts
4. **Consider template system** - Variable placeholders needed

### 2. Implementation Phase

```bash
# 1. Create your script
cp templates/shared/scripts/template.sh templates/shared/scripts/your-script.sh

# 2. Implement core functionality
# ... edit your-script.sh ...

# 3. Make executable
chmod +x templates/shared/scripts/your-script.sh

# 4. Test basic functionality
./templates/shared/scripts/your-script.sh --help
./templates/shared/scripts/your-script.sh --version
```

### 3. Integration Phase

```bash
# 1. Test with compatibility layer
./templates/shared/scripts/utils/migrate_to_compat.sh --analyze your-script.sh

# 2. Test on multiple platforms (if possible)
# - Linux (Ubuntu/CentOS/Arch)
# - macOS (Intel/Apple Silicon)
# - Windows (WSL/MSYS2/Cygwin)

# 3. Update documentation
# Add your script to README.md
# Update CONTRIBUTING.md if needed
```

## 🧪 Testing Guidelines

### Unit Testing

For complex functions, create test scripts:

```bash
# Create test file
cat > test_your_script.sh << 'EOF'
#!/usr/bin/env bash
source "$(dirname "$0")/your-script.sh"

# Test helper function
test_helper_function() {
    local expected="expected_result"
    local actual=$(your_helper_function "input")
    
    if [[ "$actual" == "$expected" ]]; then
        echo "✅ test_helper_function passed"
    else
        echo "❌ test_helper_function failed: expected '$expected', got '$actual'"
        return 1
    fi
}

# Run tests
test_helper_function
EOF

chmod +x test_your_script.sh
./test_your_script.sh
```

### Integration Testing

Test script interactions:

```bash
# Test script help
./your-script.sh --help

# Test invalid arguments
./your-script.sh --invalid-option 2>/dev/null && echo "Should have failed"

# Test dry-run mode
./your-script.sh --dry-run

# Test with various configurations
./your-script.sh --verbose
./your-script.sh --quiet
```

### Platform Testing

Use the migration tool to check compatibility:

```bash
# Analyze for platform-specific code
./templates/shared/scripts/utils/migrate_to_compat.sh --analyze your-script.sh

# Check for common issues
grep -n "uname\|nproc\|sysctl" your-script.sh
```

## 📚 Documentation Requirements

### 1. Inline Documentation

- **Function comments**: Explain purpose, parameters, return values
- **Complex logic**: Add comments for non-obvious code
- **External dependencies**: Document required tools/libraries

```bash
# Check if compiler is available and return version
# Arguments:
#   $1 - compiler command (e.g., gcc, clang++)
# Returns:
#   0 if compiler found, 1 otherwise
# Outputs:
#   Compiler version string
check_compiler() {
    local compiler="$1"
    
    if ! command -v "$compiler" >/dev/null 2>&1; then
        log_error "Compiler not found: $compiler"
        return 1
    fi
    
    "$compiler" --version | head -n1
}
```

### 2. Help Documentation

Provide comprehensive help with:

- **Purpose**: What the script does
- **Usage**: Command syntax
- **Options**: All available flags and arguments
- **Examples**: Common use cases
- **Dependencies**: Required external tools

### 3. README Updates

When adding new scripts, update the main README.md:

1. Add to appropriate category table
2. Include in workflow examples
3. Update troubleshooting if needed
4. Add to dependency graph

## 🔄 Submission Process

### 1. Pre-submission Checklist

- [ ] Script follows naming conventions
- [ ] Includes required features (help, version, error handling)
- [ ] Uses compatibility layer functions
- [ ] Tested on at least one platform
- [ ] Documentation is complete
- [ ] README.md updated

### 2. Code Review Process

1. **Create feature branch**:
   ```bash
   git checkout -b feature/add-new-script
   ```

2. **Commit with descriptive message**:
   ```bash
   git add templates/shared/scripts/your-script.sh
   git commit -m "feat(scripts): add your-script.sh for specific purpose
   
   - Implements core functionality
   - Includes cross-platform support
   - Adds comprehensive help documentation
   - Updates README.md with script information"
   ```

3. **Push and create pull request**:
   ```bash
   git push origin feature/add-new-script
   # Create PR through GitHub/GitLab interface
   ```

### 3. Review Criteria

Your contribution will be reviewed for:

- **Functionality**: Does it work as intended?
- **Compatibility**: Works across platforms?
- **Code Quality**: Follows conventions and best practices?
- **Documentation**: Adequate help and comments?
- **Integration**: Fits well with existing scripts?

## 🔧 Common Patterns

### Error Handling

```bash
# Check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    for tool in required_tool1 required_tool2; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Install with: sudo apt-get install ${missing_tools[*]}"
        return 1
    fi
}
```

### Configuration Management

```bash
# Load configuration from file or environment
load_config() {
    # Default values
    SETTING_ONE="default_value"
    SETTING_TWO=false
    
    # Load from config file if exists
    local config_file="$HOME/.script-config"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
    fi
    
    # Override with environment variables
    SETTING_ONE="${SCRIPT_SETTING_ONE:-$SETTING_ONE}"
    SETTING_TWO="${SCRIPT_SETTING_TWO:-$SETTING_TWO}"
}
```

### Progress Indication

```bash
# Show progress for long operations
show_progress() {
    local current="$1"
    local total="$2"
    local task="$3"
    
    local percent=$((current * 100 / total))
    printf "\r🔄 %s: %d%% (%d/%d)" "$task" "$percent" "$current" "$total"
    
    if [[ "$current" -eq "$total" ]]; then
        echo ""  # New line when complete
    fi
}
```

## 🎯 Best Practices

### Performance

- **Use built-in shell features** instead of external commands when possible
- **Cache expensive operations** (tool detection, version checks)
- **Parallelize independent operations** where beneficial
- **Provide incremental modes** for large operations

### Security

- **Validate all inputs** before use
- **Use absolute paths** for critical operations
- **Avoid eval** and similar dynamic execution
- **Quote variables** to prevent word splitting

### Maintainability

- **Keep functions small** and focused
- **Use descriptive variable names**
- **Avoid global state** when possible
- **Make dependencies explicit**

## 🆘 Getting Help

If you need assistance:

1. **Check existing scripts** for similar patterns
2. **Review the compatibility guide** (`utils/PLATFORM_COMPAT_GUIDE.md`)
3. **Ask questions** in issues or discussions
4. **Provide context** when reporting problems

## 📋 Script Categories

### Core Development Scripts
- Build management and compilation
- Test execution and reporting
- Code formatting and linting
- Static analysis integration

### Maintenance Scripts
- Cleanup and cache management
- Dependency updates
- Version management
- Environment setup

### CI/CD Integration
- Continuous integration workflows
- Package creation and distribution
- Deployment automation
- Documentation generation

### Utility Scripts
- Cross-platform compatibility
- Migration and setup tools
- Helper functions and libraries
- Configuration management

Thank you for contributing to {{ project_name }}! Your efforts help make the development experience better for everyone. 