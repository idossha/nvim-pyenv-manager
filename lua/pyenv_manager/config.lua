-- Configuration module for pyenv_manager
local M = {}

-- Default configuration
M.options = {
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
  keymap_run_script = ",r",
  
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

-- Setup function to merge user config with defaults
function M.setup(opts)
  if opts then
    M.options = vim.tbl_deep_extend("force", M.options, opts)
  end
end

return M
