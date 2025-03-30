-- Lualine integration for pyenv_manager
local M = {}

local config = require("pyenv_manager.config")

-- The component function
function M.env_component()
  local env_name = vim.g.pyenv_manager_env_name
  local env_type = vim.g.pyenv_manager_env_type
  
  if env_name and type(env_name) == "string" and env_name ~= "" then
    return config.options.lualine.icon .. env_name
  end
  
  return ""
end

-- Get the component configuration for lualine
function M.get_component()
  return {
    M.env_component,
    color = config.options.lualine.color,
    cond = function()
      return vim.g.pyenv_manager_env_name ~= nil
    end,
  }
end

-- Register component with lualine (for manual registration)
function M.setup_lualine()
  if config.options.lualine.enabled then
    local ok, lualine = pcall(require, "lualine")
    if not ok then
      return false
    end
    
    local lualine_config = lualine.get_config()
    if not lualine_config then
      return false
    end
    
    local section = config.options.lualine.section
    if not lualine_config.sections[section] then
      lualine_config.sections[section] = {}
    end
    
    table.insert(lualine_config.sections[section], M.get_component())
    lualine.setup(lualine_config)
    return true
  end
  return false
end

return M
