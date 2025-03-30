-- Environment detection and management module for pyenv_manager
local M = {}

local config = require("pyenv_manager.config")

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

-- Restart Python LSP servers
function M.restart_python_lsp(python_path)
  -- Check if nvim-lspconfig is available
  local has_lspconfig, _ = pcall(require, "lspconfig")
  if not has_lspconfig then
    return
  end
  
  -- Get a list of running LSP clients
  local get_clients = vim.lsp.get_active_clients or vim.lsp.get_clients
  local python_clients = get_clients({name = "pyright"})
  
  if #python_clients == 0 then
    vim.notify("No pyright LSP server running", vim.log.levels.WARN)
    return
  end
  
  -- Update settings for pyright
  for _, client in ipairs(python_clients) do
    -- Create settings structure if it doesn't exist
    client.config = client.config or {}
    client.config.settings = client.config.settings or {}
    client.config.settings.python = client.config.settings.python or {}
    client.config.settings.python.analysis = client.config.settings.python.analysis or {}
    
    -- Update Python path
    client.config.settings.python.pythonPath = python_path
    
    -- Set diagnostics mode to workspace 
    client.config.settings.python.analysis.diagnosticMode = "workspace"
    client.config.settings.python.analysis.reportMissingImports = true
    client.config.settings.python.analysis.reportMissingModuleSource = true
    client.config.settings.python.analysis.typeCheckingMode = "basic"
    
    -- Find site-packages path and add to extraPaths
    local site_packages_path
    if vim.fn.has("win32") == 1 then
      site_packages_path = vim.fn.fnamemodify(python_path, ":h:h") .. "/Lib/site-packages"
    else
      site_packages_path = vim.fn.fnamemodify(python_path, ":h:h") .. "/lib/python3*/site-packages"
      site_packages_path = vim.fn.glob(site_packages_path)
      if site_packages_path == "" then
        site_packages_path = vim.fn.fnamemodify(python_path, ":h:h") .. "/lib/site-packages"
      end
    end
    
    -- Add site-packages to extraPaths if it exists
    if site_packages_path ~= "" and vim.fn.isdirectory(site_packages_path) == 1 then
      client.config.settings.python.analysis.extraPaths = { site_packages_path }
    end
    
    -- Notify LSP of configuration change
    client.notify('workspace/didChangeConfiguration', { settings = nil })
    
    vim.notify("Updated pyright to use Python: " .. python_path, vim.log.levels.INFO)
  end
  
  -- Enable diagnostics
  vim.diagnostic.enable()
  
  -- Force refresh current buffer
  vim.defer_fn(function()
    vim.cmd("edit!")
  end, 1000)
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
    local python_path = M.get_python_path(env)
    vim.g.python3_host_prog = python_path
    
    -- Restart Python LSP servers
    M.restart_python_lsp(python_path)
    
    -- Apply sys.path changes by setting PYTHONPATH
    -- This helps with import resolution
    local site_packages_path
    if vim.fn.has("win32") == 1 then
      site_packages_path = vim.fn.fnamemodify(python_path, ":h:h") .. "/Lib/site-packages"
    else
      site_packages_path = vim.fn.fnamemodify(python_path, ":h:h") .. "/lib/python3*/site-packages"
      site_packages_path = vim.fn.glob(site_packages_path)
      if site_packages_path == "" then
        site_packages_path = vim.fn.fnamemodify(python_path, ":h:h") .. "/lib/site-packages"
      end
    end
    
    -- Only set PYTHONPATH if we found a valid site-packages path
    if site_packages_path ~= "" and vim.fn.isdirectory(site_packages_path) == 1 then
      -- Get any existing PYTHONPATH
      local existing_pythonpath = vim.env.PYTHONPATH or ""
      -- Set the PYTHONPATH to include the site-packages directory
      vim.env.PYTHONPATH = site_packages_path .. (existing_pythonpath ~= "" and (":" .. existing_pythonpath) or "")
    end
    
    return true
  elseif env.type == "conda" and M.is_conda_available() then
    -- For conda environments
    local conda_prefix = env.path
    local bin_dir = vim.fn.has("win32") == 1 and "Scripts" or "bin"
    local env_path = conda_prefix .. "/" .. bin_dir
    
    -- Update PATH
    vim.env.PATH = env_path .. (vim.fn.has("win32") == 1 and ";" or ":") .. vim.env.PATH
    vim.env.CONDA_PREFIX = conda_prefix
    
    -- Update Python path for LSP
    local python_path = M.get_python_path(env)
    vim.g.python3_host_prog = python_path
    
    -- Restart Python LSP servers
    M.restart_python_lsp(python_path)
    
    -- Apply sys.path changes by setting PYTHONPATH
    -- This helps with import resolution
    local site_packages_path
    if vim.fn.has("win32") == 1 then
      site_packages_path = conda_prefix .. "/Lib/site-packages"
    else
      -- Try to find the site-packages directory for this conda env
      local cmd = "ls -d " .. conda_prefix .. "/lib/python*/site-packages 2>/dev/null || echo ''"
      local handle = io.popen(cmd)
      if handle then
        site_packages_path = handle:read("*a"):gsub("%s+$", "")
        handle:close()
      end
      
      -- Fallback if we couldn't find it with the command
      if site_packages_path == "" then
        site_packages_path = vim.fn.glob(conda_prefix .. "/lib/python*/site-packages")
      end
      
      -- Last resort fallback
      if site_packages_path == "" then
        site_packages_path = conda_prefix .. "/lib/site-packages"
      end
    end
    
    -- Only set PYTHONPATH if we found a valid site-packages path
    if site_packages_path ~= "" and vim.fn.isdirectory(site_packages_path) == 1 then
      -- Get any existing PYTHONPATH
      local existing_pythonpath = vim.env.PYTHONPATH or ""
      -- Set the PYTHONPATH to include the site-packages directory
      vim.env.PYTHONPATH = site_packages_path .. (existing_pythonpath ~= "" and (":" .. existing_pythonpath) or "")
    end
    
    return true
  else
    return false
  end
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
  
  -- Clear PYTHONPATH
  vim.env.PYTHONPATH = nil
  
  -- Reset Python path
  vim.g.python3_host_prog = vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
  
  -- Restart LSP servers with default Python
  M.restart_python_lsp(vim.g.python3_host_prog)
  
  return true
end

return M
