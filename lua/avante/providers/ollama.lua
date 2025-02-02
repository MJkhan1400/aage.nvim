local Utils = require("avante.utils")
local P = require("avante.providers")
local Config = require("avante.config")

---@class OllamaProvider
local Ollama = {}

Ollama.api_url = "http://localhost:11434/api/generate"

-- Function to pull an Ollama model
---@param model string
---@param callback function
Ollama.pull_model = function(model, callback)
  if not model or model == "" then
    Utils.error("No model specified. Please provide a model name.")
    return
  end

  -- Run the shell command asynchronously
  local cmd = "ollama pull " .. model
  vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        Utils.info("Model '" .. model .. "' pulled successfully.")
        Config.provider = "ollama"  -- Set the provider to Ollama
        Config.ollama_model = model  -- Save the selected model
        if callback then callback(true) end
      else
        Utils.error("Failed to pull model '" .. model .. "'.")
        if callback then callback(false) end
      end
    end,
  })
end

-- Function to generate a response using Ollama
---@param opts AvantePromptOptions
Ollama.parse_curl_args = function(opts)
  local model = Config.ollama_model or "deepseek-coder"  -- Default to deepseek-coder if not set

  return {
    url = Ollama.api_url,
    headers = { ["Content-Type"] = "application/json" },
    body = vim.json.encode({
      model = model,
      prompt = opts.system_prompt,
      messages = opts.messages,
      stream = true,
    }),
  }
end

return Ollama

