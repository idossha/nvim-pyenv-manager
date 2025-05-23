# nvim-pyenv-manager

A Neovim plugin for managing Python virtual environments and conda environments with lualine integration and script running capabilities.

![PyEnv Manager Demo](https://raw.githubusercontent.com/idossha/nvim-pyenv-manager/main/assets/demo.gif)

## Features

- 🔍 **Environment Discovery**: Automatically finds and lists both venv and conda environments
- 🔄 **Environment Switching**: Easily switch between Python environments using Telescope
- 📊 **Status Display**: Shows the active environment in your lualine status bar
- 🔌 **LSP Integration**: Automatically configures Python LSP to use the selected environment
- 🌟 **Project-Aware**: Identifies project-specific environments in parent directories
- 🧠 **Smart Detection**: Auto-detects active environments on startup
- 🚀 **Script Runner**: Run Python scripts directly from Neovim using the selected environment with a single keystroke

## Installation

### Using lazy.nvim

```lua
{
  "idossha/nvim-pyenv-manager",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lualine/lualine.nvim",
  },
  config = true,
}
```

### Using packer.nvim

```lua
use {
  'idossha/nvim-pyenv-manager',
  requires = {
    'nvim-telescope/telescope.nvim',
    'nvim-lualine/lualine.nvim',
  },
  config = function()
    require('pyenv_manager').setup()
  end
}
```

## Configuration

The plugin works with default settings, but you can customize it to suit your needs:

```lua
require('pyenv_manager').setup({
  -- Search paths for virtual environments
  venv_paths = {
    vim.fn.expand("~/.virtualenvs"),  -- virtualenvwrapper
    vim.fn.getcwd(),                  -- Current directory
    vim.fn.expand("~/Projects"),      -- Projects folder
  },
  
  -- Paths for conda environments
  conda_paths = {
    vim.fn.expand("~/miniconda3/envs"),
    vim.fn.expand("~/anaconda3/envs"),
    vim.fn.expand("~/miniforge3/envs"),
  },
  
  -- Names to look for within directories for venvs
  venv_names = {
    "venv",
    ".venv",
    "env",
    ".env",
    "virtualenv",
  },
  
  -- Whether to scan parent directories for venvs
  parents = 2,  -- Number of parent directories to check
  
  -- Whether to show conda envs
  show_conda = true,
  
  -- Whether to activate the selected environment immediately
  auto_activate = true,
  
  -- Hooks when environment changes
  changed_env_hooks = {},
  
  -- Whether to create default mappings
  create_mappings = true,
  
  -- Default keymap for environment selection
  keymap_select = ",v",
  
  -- Default keymap for running Python scripts
  keymap_run_script = ",,",
  
  -- Auto-detect environment on startup
  auto_detect_on_start = true,
  
  -- Run script configuration
  run_in_terminal = true,     -- Whether to run scripts in a terminal buffer
  terminal_height = 15,       -- Height of the terminal window when running scripts
  
  -- Lualine configuration
  lualine = {
    enabled = true,
    icon = "󰆧 ", -- Python icon
    color = { fg = "#a9dc76" },  -- Green color
    section = "lualine_x", -- Where to show it
  },
})
```

## Lualine Integration

To show the active environment in lualine, add the component to your lualine configuration:

```lua
local python_env = require("pyenv_manager.lualine").get_component()

require("lualine").setup({
  sections = {
    lualine_x = {
      python_env,
      "encoding",
      "fileformat",
      "filetype",
    },
  },
})
```

## Usage

### Commands

The plugin provides the following commands:

- `:PyenvSelect` - Open the environment picker
- `:PyenvDeactivate` - Deactivate the current environment
- `:PyenvInfo` - Show information about the active environment
- `:PyenvRunScript` - Run the current Python script with the active environment

### Keymaps

By default, the plugin provides the following keymaps:

- `,v` - Open the environment selector
- `,,` - Run the current Python script with the active environment

When running scripts:
- The terminal opens in normal mode for easy navigation with hjkl
- Press `q` to close the terminal window
- Terminal shows environment info and script path

You can change these keymaps and behaviors in the configuration.

## How It Works

1. **Environment Discovery**:
   - Scans configured directories for virtual environments
   - Detects conda environments in standard locations
   - Identifies venvs in parent directories of the current project

2. **Environment Activation**:
   - Updates PATH to prioritize the selected environment
   - Sets appropriate environment variables (VIRTUAL_ENV or CONDA_PREFIX)
   - Configures Python executable path for Neovim and LSP
   - Handles special environments with custom activation scripts (like SimNIBS)

3. **Status Display**:
   - Updates lualine with the name of the active environment
   - Shows a distinctive icon to indicate the environment type

4. **Script Execution**:
   - Runs Python scripts with the active environment's interpreter
   - Shows environment information and script path in the terminal
   - Displays output in a terminal window for easy viewing and navigation
   - Terminal closes with a simple 'q' keypress

## Troubleshooting

If you encounter issues:

1. **Environment not appearing in list**:
   - Check your `venv_paths` and `conda_paths` settings
   - Ensure the environment has the expected structure

2. **LSP not using the selected environment**:
   - Restart the LSP server with `:LspRestart`
   - Verify the Python path with `:lua print(vim.g.python3_host_prog)`

3. **Environment not showing in lualine**:
   - Make sure the lualine component is added to your configuration
   - Check if the environment is properly activated with `:PyenvInfo`
   - Force a lualine refresh with `:redrawstatus`

4. **Script runner not working**:
   - Make sure an environment is active (check with `:PyenvInfo`)
   - Verify the current file is a Python file (`.py` extension)
   - Check terminal settings in your configuration

5. **Special environments not loading correctly**:
   - For conda environments with custom paths (like SimNIBS), check activation scripts
   - Verify that PYTHONPATH is set correctly with the debug output

## License

MIT

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests.
