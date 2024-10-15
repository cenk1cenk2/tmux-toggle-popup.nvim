local M = {}

M.popup_name_placeholder = "##{@popup_name}"

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

  if type(ui.width) == "number" and ui.width <= 1 and ui.width > 0 then
    result.width = math.floor(vim.o.columns * ui.width)
  elseif type(ui.width) == "function" then
    result.width = ui.width(vim.o.columns)
    if type(result.width) == "number" and result.width <= 1 and result.width > 0 then
      result.width = M.calculate_ui(result).width
    end
  end

  if type(ui.height) == "number" and ui.height <= 1 and ui.height > 0 then
    result.height = math.floor(vim.o.lines * ui.height)
  elseif type(ui.height) == "function" then
    result.height = ui.height(vim.o.lines)
    if type(result.height) == "number" and result.height <= 1 and result.height > 0 then
      result.height = M.calculate_ui(result).height
    end
  end

  -- normalize to percentage
  result.width = math.floor(result.width / vim.o.columns * 100)
  result.height = math.floor(result.height / vim.o.lines * 100)

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
function M.escape_popup_name(str)
  str = str:gsub("#{@popup_name}", M.popup_name_placeholder)

  return str
end

function M.interpolate_popup_name(str, popup_name)
  str = str:gsub(M.popup_name_placeholder, popup_name)

  return str
end

---@param commands string[]
---@return string
function M.tmux_escape(commands)
  local command = table.concat(commands, "; ")

  command = command:gsub(";", "\\;")

  return "'" .. command .. "'"
end

return M
