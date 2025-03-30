-- Environment detection and management module for pyenv-manager
local M = {}

local config = require("pyenv-manager.config")

-- Find all virtual environments
function M.find_venvs()
  local venvs = {}
  
  -- Search in predefined paths
  for _, path in ipairs(config.options.venv_paths) do
    if vim.fn.isdirectory(path) == 1 then
      -- Check if the path itself is a venv
      if M.is_venv(path) then
        table.insert(venvs, { path = path, name = vim.fn.fnamemodify(path, ":t"), type = "venv" })
      end
      
      -- Check for venvs in subdirectories
      local entries = vim.fn.glob(path .. "/*", false, true)
      for _, entry in ipairs(entries) do
        if vim.fn.isdirectory(entry) == 1 then
          -- Check if entry is a venv
          if M.is_venv(entry) then
            table.insert(venvs, { path = entry, name = vim.fn.fnamemodify(entry, ":t"), type = "venv" })
          else
            -- Check for venv names in subdirectories
            for _, venv_name in ipairs(config.options.venv_names) do
              local venv_path = entry .. "/" .. venv_name
              if vim.fn.isdirectory(venv_path) == 1 and M.is_venv(venv_path) then
                local proj_name = vim.fn.fnamemodify(entry, ":t")
                table.insert(venvs, { 
                  path = venv_path, 
                  name = proj_name .. " (" .. venv_name .. ")", 
                  type = "venv" 
                })
              end
            end
          end
        end
      end
    end
  end
  
  -- Check parent directories for venvs
  local current_dir = vim.fn.getcwd()
  local parent_dir = current_dir
  for i = 1, config.options.parents do
    for _, venv_name in ipairs(config.options.venv_names) do
      local venv_path = parent_dir .. "/" .. venv_name
      if vim.fn.isdirectory(venv_path) == 1 and M.is_venv(venv_path) then
        table.insert(venvs, { 
          path = venv_path, 
          name = "parent" .. i .. " (" .. venv_name .. ")", 
          type = "venv" 
        })
      end
    end
    parent_dir = vim.fn.fnamemodify(parent_dir, ":h")
    if parent_dir == "/" or parent_dir:match("^%a:[\\/]$") then
      break
    end
  end
  
  return venvs
end

-- Check if a directory is a valid venv
function M.is_venv(path)
  return vim.fn.filereadable(path .. "/bin/activate") == 1 or 
         vim.fn.filereadable(path .. "/Scripts/activate.bat") == 1
end

-- Find conda environments
function M.find_conda_envs()
  if not config.options.show_conda then
    return {}
  end
  
  local conda_envs = {}
  
  for _, path in ipairs(config.options.conda_paths) do
    if vim.fn.isdirectory(path) == 1 then
      local entries = vim.fn.glob(path .. "/*", false, true)
      for _, entry in ipairs(entries) do
        if vim.fn.isdirectory(entry) == 1 and M.is_conda_env(entry) then
          table.insert(conda_envs, { 
            path = entry, 
            name = "conda: " .. vim.fn.fnamemodify(entry, ":t"),
            type = "conda" 
          })
        end
      end
    end
  end
  
  return conda_envs
end

-- Check if a directory is a valid conda env
function M.is_conda_env(path)
  return vim.fn.isdirectory(path .. "/bin") == 1 or 
         vim.fn.isdirectory(path .. "/Scripts") == 1
end

-- Check if conda is available
function M.is_conda_available()
  return vim.fn.executable("conda") == 1
end

-- Get the path to the Python executable
function M.get_python_path(env)
  if not env then return nil end
  
  local bin_dir = vim.fn.has("win32") == 1 and "Scripts" or "bin"
  local python_exe = vim.fn.has("win32") == 1 and "python.exe" or "python"
  
  return env.path .. "/" .. bin_dir .. "/" .. python_exe
end

-- Detect currently active environment
function M.detect_active()
  -- Check for venv
  local venv = vim.env.VIRTUAL_ENV
  if venv and venv ~= "" then
    return {
      path = venv,
      name = vim.fn.fnamemodify(venv, ":t"),
      type = "venv"
    }
  end
  
  -- Check for conda
  local conda = vim.env.CONDA_PREFIX
  if conda and conda ~= "" then
    return {
      path = conda,
      name = "conda: " .. vim.fn.fnamemodify(conda, ":t"),
      type = "conda"
    }
  end
  
  return nil
end

-- Activate an environment
function M.activate(env)
  if env.type == "venv" then
    -- For virtual environments
    local bin_dir = vim.fn.has("win32") == 1 and "Scripts" or "bin"
    local env_path = env.path .. "/" .. bin_dir
    
    -- Update PATH
    vim.env.PATH = env_path .. (vim.fn.has("win32") == 1 and ";" or ":") .. vim.env.PATH
    vim.env.VIRTUAL_ENV = env.path
    
    -- Update Python path for LSP
    vim.g.python3_host_prog = M.get_python_path(env)
  elseif env.type == "conda" and M.is_conda_available() then
    -- For conda environments
    local conda_prefix = env.path
    local bin_dir = vim.fn.has("win32") == 1 and "Scripts" or "bin"
    local env_path = conda_prefix .. "/" .. bin_dir
    
    -- Update PATH
    vim.env.PATH = env_path .. (vim.fn.has("win32") == 1 and ";" or ":") .. vim.env.PATH
    vim.env.CONDA_PREFIX = conda_prefix
    
    -- Update Python path for LSP
    vim.g.python3_host_prog = M.get_python_path(env)
  else
    return false
  end
  
  return true
end

-- Deactivate an environment
function M.deactivate(env, previous_path)
  -- Restore previous PATH
  if previous_path then
    vim.env.PATH = previous_path
  end
  
  -- Clear environment variables
  if env.type == "venv" then
    vim.env.VIRTUAL_ENV = nil
  elseif env.type == "conda" then
    vim.env.CONDA_PREFIX = nil
  end
  
  -- Reset Python path
  vim.g.python3_host_prog = vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
  
  return true
end

return M
