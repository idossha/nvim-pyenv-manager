-- Title: Python Environment Manager for Neovim
-- Description: Manage Python environments (venv and conda) with Telescope and lualine integration
-- Author: Your Name
-- License: MIT

-- Prevent loading the plugin multiple times
if vim.g.loaded_pyenv_manager == 1 then
  return
end
vim.g.loaded_pyenv_manager = 1

-- Set up default commands that don't require the plugin to be initialized
vim.api.nvim_create_user_command("PyenvSelect", function()
  require("pyenv-manager").select_env()
end, { desc = "Select Python environment" })

vim.api.nvim_create_user_command("PyenvDeactivate", function()
  require("pyenv-manager").deactivate_env()
end, { desc = "Deactivate Python environment" })

vim.api.nvim_create_user_command("PyenvInfo", function()
  require("pyenv-manager").show_info()
end, { desc = "Show Python environment info" })
