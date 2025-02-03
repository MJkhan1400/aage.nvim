local Config = require("avante.config")

local M = {}

-- Get a short status string showing the current provider and model
M.get_model_status = function()
  local provider = Config.provider or "none"
  local model = "unknown"
  
  if provider == "ollama" then
    model = Config.ollama_model or "deepseek-coder"
  elseif provider == "openai" then
    model = Config.openai.model or "unknown"
  elseif provider == "claude" then
    model = Config.claude.model or "unknown"
  end
  
  -- Truncate model name if too long
  if #model > 20 then
    model = string.sub(model, 1, 17) .. "..."
  end
  
  return string.format("AI: %s/%s", provider, model)
end

-- Setup status line integration
M.setup = function()
  -- Add status line component if user has lualine
  local has_lualine, lualine = pcall(require, "lualine")
  if has_lualine then
    lualine.setup {
      sections = {
        lualine_x = {
          {
            M.get_model_status,
            cond = function()
              return Config.provider ~= nil
            end,
          },
        },
      },
    }
  end
end

return M 