import os
import re

def rename_module_references(directory):
    """
    Recursively process all Lua files in the given directory and its subdirectories,
    replacing 'pyenv-manager' with 'pyenv_manager' in all require statements and file paths.
    
    Args:
        directory (str): The root directory to start searching from
    """
    # List of patterns to search and replace
    patterns = [
        # Replace in require statements
        (r'require\(["\']pyenv-manager([^"\']*)["\']', r'require("pyenv_manager\1"'),
        (r"require\(['\"]pyenv-manager([^'\"]*)['\"]", r"require('pyenv_manager\1')"),
        
        # Replace in variable names and comments
        (r'pyenv-manager', r'pyenv_manager'),
        
        # Replace in vim global variables
        (r'vim\.g\.loaded_pyenv-manager', r'vim.g.loaded_pyenv_manager'),
        (r'vim\.g\.pyenv-manager_', r'vim.g.pyenv_manager_'),
    ]
    
    # File extensions to process
    lua_extensions = ['.lua']
    
    # Walk through the directory
    for root, dirs, files in os.walk(directory):
        for file in files:
            # Check if the file has a Lua extension
            if any(file.endswith(ext) for ext in lua_extensions):
                file_path = os.path.join(root, file)
                
                # Read the file content
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Apply all search and replace patterns
                modified_content = content
                for pattern, replacement in patterns:
                    modified_content = re.sub(pattern, replacement, modified_content)
                
                # If the content was modified, write it back to the file
                if modified_content != content:
                    print(f"Updating file: {file_path}")
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(modified_content)
    
    # Rename any files or directories with "pyenv-manager" in their name
    for root, dirs, files in os.walk(directory, topdown=False):
        # Rename files
        for file in files:
            if "pyenv-manager" in file:
                old_path = os.path.join(root, file)
                new_path = os.path.join(root, file.replace("pyenv-manager", "pyenv_manager"))
                print(f"Renaming file: {old_path} -> {new_path}")
                os.rename(old_path, new_path)
        
        # Rename directories
        for dir_name in dirs:
            if "pyenv-manager" in dir_name:
                old_path = os.path.join(root, dir_name)
                new_path = os.path.join(root, dir_name.replace("pyenv-manager", "pyenv_manager"))
                print(f"Renaming directory: {old_path} -> {new_path}")
                os.rename(old_path, new_path)

if __name__ == "__main__":
    # Replace with the path to your project's root directory
    project_directory = "/Users/idohaber/Git-Projects/nvim-pyenv-manager"
    rename_module_references(project_directory)
    print("Renaming completed successfully!")
