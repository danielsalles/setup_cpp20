#!/usr/bin/env python3
"""
Template Processing System for C++20 Project Generator

This module provides functionality to process Jinja2 templates and generate
project files with proper variable substitution.
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import Dict, Any, Optional, List
from jinja2 import Environment, FileSystemLoader, select_autoescape, TemplateNotFound


class TemplateProcessor:
    """
    Template processor using Jinja2 for C++20 project generation.
    
    This class handles template loading, variable substitution, and file generation
    for different project types (console, library).
    """
    
    def __init__(self, templates_dir: str = "templates"):
        """
        Initialize the template processor.
        
        Args:
            templates_dir: Directory containing the template files
        """
        self.templates_dir = Path(templates_dir)
        if not self.templates_dir.exists():
            raise ValueError(f"Templates directory '{templates_dir}' does not exist")
        
        # Setup Jinja2 environment
        self.env = Environment(
            loader=FileSystemLoader(self.templates_dir),
            autoescape=select_autoescape(['html', 'xml']),
            trim_blocks=True,
            lstrip_blocks=True
        )
        
        # Add custom filters
        self.env.filters['default'] = self._default_filter
        self.env.filters['to_cpp_identifier'] = self._to_cpp_identifier_filter
        
    def _default_filter(self, value: Any, default_value: Any = '') -> Any:
        """Custom default filter for Jinja2 templates."""
        return value if value is not None and value != '' else default_value
    
    def _to_cpp_identifier_filter(self, value: str) -> str:
        """Convert string to valid C++ identifier by replacing hyphens with underscores."""
        if not value:
            return value
        # Replace hyphens with underscores
        result = value.replace('-', '_')
        # Ensure it starts with letter or underscore (basic validation)
        if result and not (result[0].isalpha() or result[0] == '_'):
            result = '_' + result
        return result
    
    def get_default_variables(self, project_type: str = "console") -> Dict[str, Any]:
        """
        Get default variables for template processing.
        
        Args:
            project_type: Type of project (console, library)
            
        Returns:
            Dictionary with default template variables
        """
        return {
            'project_name': 'MyProject',
            'project_version': '1.0.0',
            'project_description': f'A modern C++20 {project_type} application',
            'project_author': 'Developer',
            'project_type': project_type,
            'cpp_standard': '20',
            'cmake_version': '3.20',
            'enable_sanitizers': True,
            'enable_warnings': True,
            'use_vcpkg': True,
            'optional_libraries': {
                'fmt': True,
                'spdlog': True,
                'catch2': True,
                'boost': False,
                'openssl': False
            }
        }
    
    def load_variables_from_file(self, config_file: str) -> Dict[str, Any]:
        """
        Load template variables from a JSON configuration file.
        
        Args:
            config_file: Path to JSON configuration file
            
        Returns:
            Dictionary with template variables
        """
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Warning: Configuration file '{config_file}' not found. Using defaults.")
            return {}
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in '{config_file}': {e}")
            return {}
    
    def merge_variables(self, *variable_dicts: Dict[str, Any]) -> Dict[str, Any]:
        """
        Merge multiple variable dictionaries with later ones taking precedence.
        
        Args:
            *variable_dicts: Variable dictionaries to merge
            
        Returns:
            Merged dictionary
        """
        result = {}
        for var_dict in variable_dicts:
            result.update(var_dict)
        return result
    
    def process_template(self, template_path: str, variables: Dict[str, Any]) -> str:
        """
        Process a single template file with the provided variables.
        
        Args:
            template_path: Relative path to template file from templates directory
            variables: Dictionary of variables for substitution
            
        Returns:
            Processed template content as string
        """
        try:
            template = self.env.get_template(template_path)
            return template.render(**variables)
        except TemplateNotFound:
            raise FileNotFoundError(f"Template '{template_path}' not found in '{self.templates_dir}'")
        except Exception as e:
            raise RuntimeError(f"Error processing template '{template_path}': {e}")
    
    def get_template_files(self, project_type: str) -> List[str]:
        """
        Get list of template files for a specific project type.
        
        Args:
            project_type: Type of project (console, library)
            
        Returns:
            List of template file paths
        """
        project_dir = self.templates_dir / project_type
        if not project_dir.exists():
            raise ValueError(f"Project type '{project_type}' not found in templates")
        
        template_files = []
        for root, dirs, files in os.walk(project_dir):
            for file in files:
                if file.endswith('.template'):
                    rel_path = os.path.relpath(os.path.join(root, file), self.templates_dir)
                    template_files.append(rel_path)
        
        return template_files
    
    def generate_project_files(self, 
                             output_dir: str, 
                             project_type: str,
                             variables: Dict[str, Any],
                             copy_shared: bool = True) -> List[str]:
        """
        Generate all project files for a specific project type.
        
        Args:
            output_dir: Directory where files will be generated
            project_type: Type of project (console, library)
            variables: Variables for template processing
            copy_shared: Whether to copy shared files (cmake modules, scripts)
            
        Returns:
            List of generated file paths
        """
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        generated_files = []
        
        # Process project-specific templates
        template_files = self.get_template_files(project_type)
        
        for template_file in template_files:
            # Process template
            content = self.process_template(template_file, variables)
            
            # Determine output file path (remove .template extension)
            rel_output_path = template_file.replace(f"{project_type}/", "").replace(".template", "")
            output_file = output_path / rel_output_path
            
            # Create output directory if needed
            output_file.parent.mkdir(parents=True, exist_ok=True)
            
            # Write processed content
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(content)
            
            generated_files.append(str(output_file))
            print(f"Generated: {output_file}")
        
        # Copy shared files if requested
        if copy_shared:
            shared_files = self._copy_shared_files(output_path, variables)
            generated_files.extend(shared_files)
        
        return generated_files
    
    def _copy_shared_files(self, output_path: Path, variables: Dict[str, Any]) -> List[str]:
        """
        Copy and process shared files (cmake modules, build scripts) to output directory.
        Shared files are processed as Jinja2 templates.
        
        Args:
            output_path: Output directory path
            variables: Dictionary of variables for substitution
            
        Returns:
            List of copied/generated file paths
        """
        shared_dir = self.templates_dir / "shared"
        if not shared_dir.exists():
            return []
        
        processed_files = []
        
        for root, dirs, files in os.walk(shared_dir):
            for file in files:
                src_file = Path(root) / file
                
                # Determine relative path from shared directory for destination
                rel_dest_path = src_file.relative_to(shared_dir)
                
                # Remove .template extension if present
                if rel_dest_path.suffix == '.template':
                    rel_dest_path = rel_dest_path.with_suffix('')
                
                dest_file = output_path / rel_dest_path
                
                # Create destination directory if needed
                dest_file.parent.mkdir(parents=True, exist_ok=True)
                
                # Determine template path relative to templates_dir for processing
                template_path_for_processing = str(src_file.relative_to(self.templates_dir))

                try:
                    # Process the file as a template
                    content = self.process_template(template_path_for_processing, variables)
                    
                    with open(dest_file, 'w', encoding='utf-8') as f:
                        f.write(content)
                    
                    print(f"Processed shared file: {dest_file}")

                except Exception as e:
                    # If processing fails (e.g., not a valid template, or binary file),
                    # fall back to copying directly for non-template or problematic files.
                    # We still want to copy files like .cmake modules that might not be templates.
                    # However, scripts (.sh) are expected to be templates.
                    if dest_file.suffix == '.sh':
                        print(f"Warning: Failed to process shared script {src_file} as template: {e}. Copying directly.")
                    import shutil
                    shutil.copy2(src_file, dest_file)
                    print(f"Copied shared file (fallback): {dest_file}")

                # Make scripts executable
                if dest_file.suffix == '.sh':
                    dest_file.chmod(0o755) # Ensure scripts are executable
                
                processed_files.append(str(dest_file))
        
        return processed_files


def main():
    """Main function for command-line usage."""
    parser = argparse.ArgumentParser(
        description="Process C++20 project templates using Jinja2",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s console MyProject
  %(prog)s library MyLibrary --config project.json
  %(prog)s console TestApp --output ./output --author "John Doe"
        """
    )
    
    parser.add_argument('project_type', choices=['console', 'library'],
                       help='Type of project to generate')
    parser.add_argument('project_name', help='Name of the project')
    parser.add_argument('--output', '-o', default='.',
                       help='Output directory (default: current directory)')
    parser.add_argument('--config', '-c',
                       help='JSON configuration file with template variables')
    parser.add_argument('--templates-dir', default='templates',
                       help='Templates directory (default: templates)')
    parser.add_argument('--no-shared', action='store_true',
                       help='Do not copy shared files (cmake modules, scripts)')
    
    # Optional template variables
    parser.add_argument('--author', help='Project author name')
    parser.add_argument('--version', help='Project version')
    parser.add_argument('--description', help='Project description')
    
    args = parser.parse_args()
    
    try:
        # Initialize processor
        processor = TemplateProcessor(args.templates_dir)
        
        # Get default variables
        variables = processor.get_default_variables(args.project_type)
        
        # Update with project name
        variables['project_name'] = args.project_name
        
        # Load variables from config file if provided
        if args.config:
            config_vars = processor.load_variables_from_file(args.config)
            variables = processor.merge_variables(variables, config_vars)
        
        # Override with command-line arguments
        cli_vars = {}
        if args.author:
            cli_vars['project_author'] = args.author
        if args.version:
            cli_vars['project_version'] = args.version
        if args.description:
            cli_vars['project_description'] = args.description
        
        if cli_vars:
            variables = processor.merge_variables(variables, cli_vars)
        
        # Generate project files
        print(f"Generating {args.project_type} project '{args.project_name}'...")
        print(f"Output directory: {os.path.abspath(args.output)}")
        print(f"Variables: {json.dumps(variables, indent=2)}")
        print()
        
        generated_files = processor.generate_project_files(
            args.output,
            args.project_type,
            variables,
            copy_shared=not args.no_shared
        )
        
        print(f"\nSuccessfully generated {len(generated_files)} files!")
        print("Project generation complete.")
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main() 