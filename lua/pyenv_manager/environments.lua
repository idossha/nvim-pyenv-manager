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

function M.restart_python_lsp(python_path)
  -- Check if nvim-lspconfig is available
  local has_lspconfig, lspconfig = pcall(require, "lspconfig")
  if not has_lspconfig then
    return
  end
  
  -- Check if pyright is available
  local has_pyright = pcall(require, "lspconfig.pyright")
  if not has_pyright then
    vim.notify("Pyright LSP not found. Please install it for better Python integration.", vim.log.levels.WARN)
    return
  end
  
  -- Find site-packages path for the selected Python environment
  local site_packages_path
  if vim.fn.has("win32") == 1 then
    -- Windows path (Library/site-packages)
    site_packages_path = vim.fn.fnamemodify(python_path, ":h:h") .. "/Lib/site-packages"
  else
    -- Unix path (lib/pythonX.Y/site-packages)
    local base_path = vim.fn.fnamemodify(python_path, ":h:h")
    local pattern = base_path .. "/lib/python3*/site-packages"
    local paths = vim.fn.glob(pattern, false, true)
    
    if #paths > 0 then
      site_packages_path = paths[1]
    else
      -- Fallback to a simple path structure
      site_packages_path = base_path .. "/lib/site-packages"
    end
  end
  
  -- Ensure python_path is executable
  if vim.fn.executable(python_path) ~= 1 then
    vim.notify("Python path is not executable: " .. python_path, vim.log.levels.ERROR)
    return
  end

  -- Stop all Python LSP servers
  local clients = vim.lsp.get_active_clients()
  for _, client in ipairs(clients) do
    if client.name == "pyright" then
      vim.lsp.stop_client(client.id, true)
    end
  end
  
  -- Update pyright configuration
  lspconfig.pyright.setup({
    capabilities = (function()
      -- Try to reuse existing capabilities if available
      local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
      if has_cmp then
        return cmp_nvim_lsp.default_capabilities()
      else
        return vim.lsp.protocol.make_client_capabilities()
      end
    end)(),
    on_attach = function(client, bufnr)
      -- Preserve existing on_attach if we can find it in the current config
      local current_config = lspconfig.pyright.manager and lspconfig.pyright.manager.config
      if current_config and current_config.on_attach then
        current_config.on_attach(client, bufnr)
      end
    end,
    settings = {
      python = {
        pythonPath = python_path,
        analysis = {
          autoSearchPaths = true,
          diagnosticMode = "workspace", -- Use workspace to analyze all files
          useLibraryCodeForTypes = true,
          typeCheckingMode = "basic", -- Enable type checking
          extraPaths = { site_packages_path }
        }
      }
    }
  })
  
  -- Force a reload of all Python files
  vim.defer_fn(function()
    -- Get all buffer numbers
    local buffers = vim.api.nvim_list_bufs()
    for _, bufnr in ipairs(buffers) do
      -- Check if the buffer is loaded and is a Python file
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        if bufname:match("%.py$") then
          -- Force reload the buffer to update diagnostics
          local winnr = vim.fn.bufwinnr(bufnr)
          if winnr > 0 then
            -- Only reload visible buffers to avoid messing with the layout
            vim.cmd(winnr .. "wincmd w")
            vim.cmd("edit!")
            -- Return to previous window
            vim.cmd("wincmd p")
          end
        end
      end
    end
    
    -- Notify user that LSP has been restarted
    vim.notify("Python LSP restarted with: " .. python_path, vim.log.levels.INFO)
  end, 1000) -- Wait 1 second for LSP to initialize
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
    local site_packages_path = vim.fn.fnamemodify(python_path, ":h:h") .. "/lib/site-packages"
    -- Get any existing PYTHONPATH
    local existing_pythonpath = vim.env.PYTHONPATH or ""
    -- Set the PYTHONPATH to include the site-packages directory
    vim.env.PYTHONPATH = site_packages_path .. (existing_pythonpath ~= "" and (":" .. existing_pythonpath) or "")
    
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
      site_packages_path = conda_prefix .. "/lib/python3.*/site-packages"
      -- Expand the wildcard to get the actual path
      local cmd = "ls -d " .. site_packages_path .. " 2>/dev/null || echo ''"
      local handle = io.popen(cmd)
      if handle then
        site_packages_path = handle:read("*a"):gsub("%s+$", "")
        handle:close()
      end
    end
    
    -- Only set PYTHONPATH if we found a valid site-packages path
    if site_packages_path ~= "" then
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
