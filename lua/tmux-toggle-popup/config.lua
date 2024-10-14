local M = {}

---@class tmux-toggle-popup.Config: tmux-toggle-popup.ToggleOpts
---@field log_level? number

---@class tmux-toggle-popup.ConfigUiSize
---@field width? number | (fun(columns: number): number?)
---@field height? number | (fun(lines: number): number?)

---@class tmux-toggle-popup.State
---@field script string

---@type tmux-toggle-popup.Config
local defaults = {
  log_level = vim.log.levels.INFO,
  name = "scratch",
  socket_name = "default",
  id_format = "#{b:socket_path}/#{session_name}/nvim/#{b:pane_current_path}/#{@popup_name}",
  command = nil,
  width = function(columns)
    if columns < 180 then
      return math.floor(columns * 0.975)
    end

    return math.floor(columns * 0.9)
  end,
  height = function(lines)
    if lines < 60 then
      return math.floor(lines * 0.95)
    end

    return math.floor(lines * 0.9)
  end,
  on_init = {
    "set exit-empty on",
    "set -g status on",
  },
  kill_on_vim_leave = false,
}

---@type tmux-toggle-popup.Config
---@diagnostic disable-next-line: missing-fields
M.options = nil

---@type tmux-toggle-popup.State
---@diagnostic disable-next-line: missing-fields
M.state = {}

---@return tmux-toggle-popup.Config
function M.read()
  return M.options or error("Setup was not called.")
end

---@param config tmux-toggle-popup.Config
---@return tmux-toggle-popup.Config
function M.setup(config)
  M.options = vim.tbl_deep_extend("force", {}, defaults, config or {})

  vim.validate({
    log_level = { M.options.log_level, "number", true },
  })

  local log = require("tmux-toggle-popup.log").setup({ level = M.options.log_level })

  if not require("tmux-toggle-popup.utils").is_tmux() then
    return config
  end

  require("plenary.job")
    :new({
      command = "tmux",
      args = {
        "show",
        "-gqv",
        "@popup-toggle",
      },
      on_exit = function(j, code)
        vim.schedule(function()
          if code > 0 then
            log.error(
              "tmux-toggle-popup plugin is not installed or not configured properly. Please install it through following instructions on https://github.com/loichyan/tmux-toggle-popup."
            )

            return
          end

          M.state.script = vim.fn.join(j:result(), "")

          log.debug("Found tmux-toggle-popup script: %s", M.state.script)
        end)
      end,
    })
    :start()

  return M.options
end

return M
