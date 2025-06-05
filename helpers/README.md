# Template Processing System

This directory contains the C++20 project template processing system using Jinja2 for variable substitution.

## Overview

The template processing system consists of:

- **`template_processor.py`**: Core Python module with Jinja2 template processing logic
- **`process_templates.sh`**: Convenient shell wrapper script
- **`project_config.example.json`**: Example configuration file for template variables

## Requirements

- Python 3.6+
- Jinja2 library

Install Jinja2:
```bash
pip install jinja2
```

## Usage

### 1. Using the Shell Wrapper (Recommended)

The shell wrapper provides a user-friendly interface:

```bash
# Basic usage
./helpers/process_templates.sh console MyProject

# With custom author and version
./helpers/process_templates.sh library MyLibrary --author "John Doe" --version "2.0.0"

# Using configuration file
./helpers/process_templates.sh console TestApp --config project.json

# Specify output directory
./helpers/process_templates.sh library NetworkLib --output ./generated_projects

# Full example with all options
./helpers/process_templates.sh console AdvancedApp \
    --output ./projects \
    --author "Jane Smith" \
    --version "1.5.0" \
    --description "An advanced C++20 console application" \
    --verbose
```

### 2. Using the Python Module Directly

```bash
# Basic usage
python3 helpers/template_processor.py console MyProject

# With configuration file
python3 helpers/template_processor.py library MyLibrary --config project.json

# Full options
python3 helpers/template_processor.py console TestApp \
    --output ./output \
    --author "Developer" \
    --version "1.0.0" \
    --description "Test application"
```

## Configuration

### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--output`, `-o` | Output directory | `--output ./projects` |
| `--config`, `-c` | JSON configuration file | `--config project.json` |
| `--templates-dir` | Templates directory | `--templates-dir ./templates` |
| `--author` | Project author name | `--author "John Doe"` |
| `--version` | Project version | `--version "2.0.0"` |
| `--description` | Project description | `--description "My app"` |
| `--no-shared` | Skip copying shared files | `--no-shared` |
| `--verbose`, `-v` | Enable verbose output | `--verbose` |

### Configuration File

You can use a JSON configuration file to specify template variables:

```json
{
  "project_name": "MyProject",
  "project_version": "1.0.0",
  "project_description": "A modern C++20 application",
  "project_author": "Your Name",
  "optional_libraries": {
    "fmt": true,
    "spdlog": true
  }
}
```

Copy `project_config.example.json` and customize it for your needs.

### Variable Precedence

Variables are applied in this order (later overrides earlier):
1. Default values
2. Configuration file values
3. Command line arguments

## Template Variables

### Core Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Project name | `MyProject` |
| `project_version` | Project version | `1.0.0` |
| `project_description` | Project description | Auto-generated |
| `project_author` | Author name | `Developer` |
| `cpp_standard` | C++ standard version | `20` |
| `cmake_version` | Minimum CMake version | `3.20` |

### Feature Flags

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_testing` | Enable testing support | `true` |
| `enable_sanitizers` | Enable sanitizers in debug builds | `true` |
| `enable_warnings` | Enable compiler warnings | `true` |
| `use_vcpkg` | Enable vcpkg integration | `true` |

### Optional Libraries

Control which optional libraries to include:

```json
{
  "optional_libraries": {
    "fmt": true,
    "spdlog": true,
    "boost": false,
    "openssl": false
  }
}
```

## Generated Project Structure

### Console Application

```
project_name/
├── CMakeLists.txt
├── main.cpp
├── .gitignore
├── cmake/
│   └── CompilerWarnings.cmake
└── scripts/
    ├── build.sh
    └── test.sh
```

### Library Project

```
project_name/
├── CMakeLists.txt
├── .gitignore
├── include/
│   └── library.hpp
├── src/
│   └── library.cpp
├── cmake/
│   └── CompilerWarnings.cmake
└── scripts/
    ├── build.sh
    └── test.sh
```

## Examples

### Example 1: Simple Console Application

```bash
./helpers/process_templates.sh console HelloWorld --output ./test_project
cd test_project
mkdir build && cd build
cmake ..
make
./HelloWorld
```

### Example 2: Library with Custom Configuration

Create `my_config.json`:
```json
{
  "project_name": "MathLibrary",
  "project_version": "2.1.0",
  "project_description": "Advanced mathematical operations library",
  "project_author": "Math Team",
  "optional_libraries": {
    "fmt": true,
    "spdlog": false
  }
}
```

Generate the library:
```bash
./helpers/process_templates.sh library MathLibrary --config my_config.json --output ./math_lib
```

### Example 3: Advanced Console App with All Features

```bash
./helpers/process_templates.sh console GameEngine \
    --output ./game_project \
    --author "Game Developer" \
    --version "0.5.0" \
    --description "A modern C++20 game engine" \
    --verbose
```

## Testing the System

Test template processing with a simple example:

```bash
# Create test directory
mkdir -p test_output

# Generate console application
./helpers/process_templates.sh console TestApp --output test_output --verbose

# Verify generated files
ls -la test_output/
cat test_output/CMakeLists.txt

# Test build
cd test_output
mkdir build && cd build
cmake ..
make
./TestApp
```

## Troubleshooting

### Common Issues

1. **Jinja2 not found**
   ```bash
   pip install jinja2
   ```

2. **Template files not found**
   - Ensure you're running from the project root
   - Check that `templates/` directory exists

3. **Permission denied**
   ```bash
   chmod +x helpers/process_templates.sh
   chmod +x helpers/template_processor.py
   ```

4. **Invalid project name**
   - Use alphanumeric characters and underscores
   - Start with a letter

### Verbose Output

Use `--verbose` flag for detailed information:
```bash
./helpers/process_templates.sh console MyApp --verbose
```

## Integration

This template processing system is part of the larger C++20 project generator foundation. It works with:

- CMake configuration generation
- Project structure creation
- Build script generation
- Template file management

For integration into other tools, use the `TemplateProcessor` Python class directly:

```python
from helpers.template_processor import TemplateProcessor

processor = TemplateProcessor("templates")
variables = processor.get_default_variables("console")
variables["project_name"] = "MyApp"

files = processor.generate_project_files("./output", "console", variables)
``` 