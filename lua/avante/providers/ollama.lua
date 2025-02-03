local Utils = require("avante.utils")
local P = require("avante.providers")
local Config = require("avante.config")
local curl = require("plenary.curl")

---@class OllamaProvider
local Ollama = {}

-- Constants for Ollama API endpoints
Ollama.GENERATE_API = "/api/generate"
Ollama.LIST_MODELS_API = "/api/tags"
Ollama.MODEL_INFO_API = "/api/show"

-- Get the base URL from config or default
Ollama.get_base_url = function()
  return (Config.ollama and Config.ollama.endpoint) or "http://localhost:11434"
end

-- Function to check if Ollama server is running
---@param callback function
Ollama.check_server = function(callback)
  curl.get(Ollama.get_base_url() .. Ollama.LIST_MODELS_API, {
    timeout = 5000,
    callback = function(response)
      if response.status == 200 then
        if callback then callback(true) end
      else
        Utils.error("Ollama server is not running at " .. Ollama.get_base_url())
        if callback then callback(false) end
      end
    end,
  })
end

-- Function to list available Ollama models
---@param callback function
Ollama.list_models = function(callback)
  curl.get(Ollama.get_base_url() .. Ollama.LIST_MODELS_API, {
    callback = function(response)
      if response.status == 200 then
        local ok, models = pcall(vim.json.decode, response.body)
        if ok and models.models then
          if callback then callback(models.models) end
        else
          Utils.error("Failed to parse models list from Ollama")
          if callback then callback({}) end
        end
      else
        Utils.error("Failed to fetch models from Ollama")
        if callback then callback({}) end
      end
    end,
  })
end

-- Function to pull an Ollama model
---@param model string
---@param callback function
Ollama.pull_model = function(model, callback)
  if not model or model == "" then
    Utils.error("No model specified. Please provide a model name.")
    return
  end

  -- Show progress notification
  Utils.info("Pulling model '" .. model .. "'. This may take a while...")

  -- Run the shell command asynchronously
  local cmd = "ollama pull " .. model
  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if data and #data > 0 then
        Utils.debug("Pull progress: " .. vim.inspect(data))
      end
    end,
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

-- Function to validate model exists
---@param model string
---@param callback function
Ollama.validate_model = function(model, callback)
  curl.post(Ollama.get_base_url() .. Ollama.MODEL_INFO_API, {
    body = vim.json.encode({ name = model }),
    headers = { ["Content-Type"] = "application/json" },
    callback = function(response)
      if response.status == 200 then
        if callback then callback(true) end
      else
        Utils.error("Model '" .. model .. "' not found. Use :OllamaPull to download it.")
        if callback then callback(false) end
      end
    end,
  })
end

-- Function to generate a response using Ollama
---@param opts AvantePromptOptions
Ollama.parse_curl_args = function(opts)
  local model = Config.ollama_model or "deepseek-coder"  -- Default to deepseek-coder if not set
  local temperature = (Config.ollama and Config.ollama.temperature) or 0
  local max_tokens = (Config.ollama and Config.ollama.max_tokens) or 8000

  -- Construct messages array from system prompt and user messages
  local messages = {}
  if opts.system_prompt then
    table.insert(messages, { role = "system", content = opts.system_prompt })
  end
  for _, msg in ipairs(opts.messages or {}) do
    table.insert(messages, msg)
  end

  return {
    url = Ollama.get_base_url() .. Ollama.GENERATE_API,
    headers = { ["Content-Type"] = "application/json" },
    body = vim.json.encode({
      model = model,
      messages = messages,
      stream = true,
      options = {
        temperature = temperature,
        max_tokens = max_tokens,
      },
    }),
  }
end

-- Add commands for Ollama integration
vim.api.nvim_create_user_command("OllamaPull", function(args)
  if args.args and args.args ~= "" then
    Ollama.pull_model(args.args, function(success)
      if success then
        Utils.info("Model pulled successfully and set as current model")
      end
    end)
  else
    Utils.error("Please specify a model name")
  end
end, {
  nargs = 1,
  complete = function()
    return { "deepseek-coder", "codellama", "mistral", "llama2" }  -- Common coding models
  end,
})

vim.api.nvim_create_user_command("OllamaListModels", function()
  Ollama.list_models(function(models)
    if models and #models > 0 then
      local model_names = {}
      for _, model in ipairs(models) do
        table.insert(model_names, model.name)
      end
      Utils.info("Available models:\n" .. table.concat(model_names, "\n"))
    end
  end)
end, {})

return Ollama

