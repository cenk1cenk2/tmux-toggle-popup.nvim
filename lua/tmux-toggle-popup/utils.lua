local M = {}

local log = require("tmux-toggle-popup.log")

local TMUX_POPUP_NAME = "#{@popup_name}"

---Check if the current environment is tmux.
---@return boolean
function M.is_tmux()
  return vim.env["TMUX"] and vim.env["TMUX"] ~= ""
end

---Calculate the size of the UI.
---@param ui tmux-toggle-popup.ConfigUiSize
---@return tmux-toggle-popup.ConfigUiSize
function M.calculate_ui(ui)
  local result = vim.deepcopy(ui)
  local columns = vim.env["COLUMNS"] or vim.o.columns
  local lines = vim.env["LINES"] or vim.o.lines

  if type(ui.width) == "number" and ui.width <= 1 and ui.width > 0 then
    result.width = math.floor(columns * ui.width)
  elseif type(ui.width) == "function" then
    result.width = ui.width(columns)
    if type(result.width) == "number" and result.width <= 1 and result.width > 0 then
      result.width = M.calculate_ui(result).width
    end
  end

  if type(ui.height) == "number" and ui.height <= 1 and ui.height > 0 then
    result.height = math.floor(lines * ui.height)
  elseif type(ui.height) == "function" then
    result.height = ui.height(lines)
    if type(result.height) == "number" and result.height <= 1 and result.height > 0 then
      result.height = M.calculate_ui(result).height
    end
  end

  -- normalize to percentage
  result.width = math.floor(result.width / columns * 100)
  result.height = math.floor(result.height / lines * 100)

  if result.width < 0 or result.width > 100 then
    error("Invalid width, after the calculations it should be a percentage: " .. result.width)
  elseif result.height < 0 or result.height > 100 then
    error("Invalid width, after the calculation it should be a percentage: " .. result.width)
  end

  return result
end

---
---@param str string
---@return  string
function M.escape_id_format(str)
  str = str:gsub(TMUX_POPUP_NAME, "#" .. TMUX_POPUP_NAME)

  return str
end

---
---@param str string
---@param popup_name string
---@return string
function M.interpolate_id_format(str, popup_name)
  str = str:gsub("#?" .. TMUX_POPUP_NAME, popup_name)

  return str
end

---
---@param id_format string
---@return string?
function M.interpolate_session_name(id_format)
  log.debug("Trying to interpolate popup name: %s", id_format)

  local result = vim
    .system({
      "tmux",
      "display",
      "-p",
      id_format,
    })
    :wait(1000)

  local session_name = result.stdout:gsub("[\n]", "")
  if result.code > 0 or session_name == "" then
    log.debug("Can not get session name for popup: %s", id_format)

    return
  end

  log.debug("Got session name for popup: %s -> %s", id_format, session_name)

  return session_name
end

---@param commands ((fun (session: tmux-toggle-popup.Session, name?: string): string) | string[])?
---@return string
function M.tmux_escape(commands, session, name)
  ---@diagnostic disable-next-line: param-type-mismatch
  for _, command in pairs(commands) do
    if type(commands) == "function" then
      command = command(session, name)
    end
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  return "'" .. table.concat(commands, "; "):gsub(";", "\\;") .. "'"
end

return M
