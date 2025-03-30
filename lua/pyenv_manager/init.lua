-- Main module for pyenv_manager
local M = {}

-- Module imports
local config = require("pyenv_manager.config")
local environments = require("pyenv_manager.environments")
local telescope_integration = require("pyenv_manager.telescope")

-- State variables
M.current_env = nil
M.current_env_type = nil
M.previous_path = nil

-- Setup function
function M.setup(opts)
  -- Load and merge configuration
  config.setup(opts)
  
  -- Create default mappings if enabled
  if config.options.create_mappings then
    local map_opts = { noremap = true, silent = true }
    vim.keymap.set("n", config.options.keymap_select, "<cmd>PyenvSelect<CR>", map_opts)
  end
  
  -- Set up autocommands
  if config.options.auto_detect_on_start then
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        vim.defer_fn(function()
          M.detect_active_env()
        end, 500)
      end,
    })
  end
  
  -- Return the module for chaining
  return M
end

-- Detect active environment
function M.detect_active_env()
  local env = environments.detect_active()
  if env then
    M.set_env_info(env)
    vim.cmd("redrawstatus")
  end
end

-- Select environment using Telescope
function M.select_env()
  telescope_integration.show_picker(function(env)
    if env.type == "deactivate" then
      M.deactivate_env()
    else
      M.activate_env(env)
    end
  end)
end

-- Activate an environment
function M.activate_env(env)
  if env == nil then
    return false
  end
  
  -- Save the previous PATH to restore later
  M.previous_path = vim.env.PATH
  M.current_env = env
  M.current_env_type = env.type
  
  -- Perform activation
  local success = environments.activate(env)
  if not success then
    vim.notify("Failed to activate environment: " .. env.name, vim.log.levels.ERROR)
    return false
  end
  
  -- Update global variable for status line
  M.set_env_info(env)
  
  -- Run hooks
  for _, hook in ipairs(config.options.changed_env_hooks) do
    hook(env)
  end
  
  vim.notify("Activated Python environment: " .. env.name, vim.log.levels.INFO)
  vim.cmd("redrawstatus")
  return true
end

-- Deactivate the current environment
function M.deactivate_env()
  if M.current_env == nil then
    vim.notify("No environment is currently active", vim.log.levels.INFO)
    return false
  end
  
  -- Perform deactivation
  environments.deactivate(M.current_env, M.previous_path)
  
  -- Clear global variable for status line
  M.set_env_info(nil)
  
  -- Run hooks
  for _, hook in ipairs(config.options.changed_env_hooks) do
    hook(nil)
  end
  
  vim.notify("Deactivated Python environment: " .. M.current_env.name, vim.log.levels.INFO)
  M.current_env = nil
  M.current_env_type = nil
  M.previous_path = nil
  vim.cmd("redrawstatus")
  return true
end

-- Show environment info
function M.show_info()
  if M.current_env == nil then
    vim.notify("No Python environment is active", vim.log.levels.INFO)
    return
  end
  
  local info = "Active Python Environment:\n"
  info = info .. "  Name: " .. M.current_env.name .. "\n"
  info = info .. "  Type: " .. M.current_env_type .. "\n"
  info = info .. "  Path: " .. M.current_env.path .. "\n"
  
  local python_path = environments.get_python_path(M.current_env)
  if python_path then
    info = info .. "  Python: " .. python_path .. "\n"
  end
  
  vim.notify(info, vim.log.levels.INFO)
end

-- Set environment info for status line
function M.set_env_info(env)
  if env then
    vim.g.pyenv_manager_env_name = env.name
    vim.g.pyenv_manager_env_type = env.type
    vim.g.pyenv_manager_env_path = env.path
  else
    vim.g.pyenv_manager_env_name = nil
    vim.g.pyenv_manager_env_type = nil
    vim.g.pyenv_manager_env_path = nil
  end
end

-- Get current environment
function M.get_current_env()
  return M.current_env
end

return M
