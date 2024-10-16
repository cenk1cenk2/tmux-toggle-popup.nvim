local M = {
  _ = {
    ---@type table<string, number>
    autocmd_to_kill = {},
    ---@type table<string, tmux-toggle-popup.SessionIdentifier>
    sessions = {},
  },
}

local config = require("tmux-toggle-popup.config")
local log = require("tmux-toggle-popup.log")
local utils = require("tmux-toggle-popup.utils")
local Job = require("plenary.job")

local AUGROUP_TO_KILL = "tmux-toggle-popup.to-kill"

---@class tmux-toggle-popup.Session: tmux-toggle-popup.ConfigUiSize, tmux-toggle-popup.SessionIdentifier
---@field socket_name string?
---@field command string[]?
---@field env table<string, string>?
---@field on_init string[]?
---@field before_open string[]?
---@field after_close string[]?
---@field kill boolean?
---@field flags tmux-toggle-popup.Flags?

---@class tmux-toggle-popup.Flags
---@field no_border boolean? --- -B does not surround the popup by a border.
---@field close boolean? --- The -C flag closes any popup on the client.
---@field close_on_exit (true | 'on-success' | false)? --- -E closes the popup automatically when shell-command exits. Two -E closes the popup only if shell-command exited with success.
---@field border string? --- -b sets the type of characters used for drawing popup borders.  When -B is specified, the -b option is ignored.  See popup-border-lines for possible values for border-lines.
---@field target_client string? --- target-client
---@field start_directory ((fun (): string | nil) | string)? --- -d directory
---@field popup_style string? --- -s sets the style for the popup (see “STYLES”).
---@field border_style string? --- -S sets the style for the popup border (see “STYLES”).
---@field target_pane string? --- target-pane
---@field title ((fun (session: tmux-toggle-popup.Session, name: string): string | nil) | string)? --- -T is a format for the popup title (see “FORMATS”).

---@class tmux-toggle-popup.SessionIdentifier
---@field name string?
---@field id_format string?

---@param opts tmux-toggle-popup.SessionIdentifier
function M.validate_session_identifier(opts)
  vim.validate({
    name = { opts.name, "string", true },
    id_format = { opts.id_format, "string", true },
  })
end

---@param opts tmux-toggle-popup.Session
function M.validate_session_options(opts)
  vim.validate({
    flags = { opts.flags, "table", true },
    id_format = { opts.id_format, "string", true },
    command = { opts.command, "table", true },
    env = { opts.env, "table", true },
    on_init = { opts.on_init, "table", true },
    before_open = { opts.before_open, "table", true },
    after_close = { opts.after_close, "table", true },
    kill = { opts.kill, "boolean", true },
    height = { opts.height, { "number", "function" }, true },
    width = { opts.height, { "number", "function" }, true },
  })
end

---@param opts tmux-toggle-popup.Flags
function M.validate_session_flags(opts)
  vim.validate({
    no_border = { opts.no_border, "boolean", true },
    close = { opts.close, "boolean", true },
    close_on_exit = { opts.close_on_exit, { "string", "boolean" }, true },
    border = { opts.border, "string", true },
    target_client = { opts.target_client, "string", true },
    start_directory = { opts.start_directory, { "function", "string" }, true },
    popup_style = { opts.popup_style, "string", true },
    border_style = { opts.border_style, "string", true },
    target_pane = { opts.target_pane, "string", true },
    title = { opts.title, { "function", "string" }, true },
  })
end

---@param opts? tmux-toggle-popup.Session
function M.open(opts)
  local c = config.read()
  ---@type tmux-toggle-popup.Session
  opts = vim.tbl_deep_extend("force", {}, c, opts or {})

  M.validate_session_identifier(opts)
  M.validate_session_options(opts)
  M.validate_session_flags(opts.flags)

  local ui = require("tmux-toggle-popup.utils").calculate_ui(opts)

  if not require("tmux-toggle-popup.utils").is_tmux() then
    log.error("Not running inside tmux, aborting.")

    return
  end

  opts.id_format = utils.escape_id_format(opts.id_format)

  local args = {
    "--toggle",
    "--name",
    opts.name,
    "--socket-name",
    opts.socket_name,
    "--id-format",
    opts.id_format,
    ("-w%s%%"):format(ui.width),
    ("-h%s%%"):format(ui.height),
  }

  local sockets = vim.fn.serverlist()
  if sockets and #sockets > 0 then
    opts.env["NVIM"] = sockets[1]
  end

  for key, value in pairs(opts.env) do
    vim.list_extend(args, { "-e", key .. "=" .. value })
  end

  if opts.on_init and #opts.on_init > 0 then
    table.insert(args, "--on-init")
    table.insert(args, utils.tmux_escape(opts.on_init))
  end

  if opts.before_open and #opts.before_open > 0 then
    table.insert(args, "--before-open")
    table.insert(args, utils.tmux_escape(opts.before_open))
  end

  if opts.after_close and #opts.after_close > 0 then
    table.insert(args, "--after-close")
    table.insert(args, utils.tmux_escape(opts.after_close))
  end

  vim.list_extend(args, M.parse_flags(opts))

  if opts.command then
    vim.list_extend(args, opts.command)
  end

  log.debug("Trying to spawn a new tmux command with: %s", args)
  Job:new({
    command = "tmux",
    args = {
      "run",
      table.concat(vim.list_extend({ "#{@popup-toggle}" }, args), " "),
    },
    detached = true,
    on_exit = function(j, code)
      if code > 0 then
        log.error("Can not spawn tmux command: %s", j:stderr_result())

        return
      end

      log.debug("Finished tmux command: %s", j:result())
    end,
  }):start()

  local session_name, id_format = M.format_identifier(opts)

  if not session_name then
    log.warn("Can not get session name for popup: %s", id_format)

    return
  end

  M._.sessions[session_name] = opts

  if opts.kill then
    M._.autocmd_to_kill[session_name] = vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
      group = vim.api.nvim_create_augroup(AUGROUP_TO_KILL, { clear = false }),
      pattern = "*",
      callback = function()
        ---@diagnostic disable-next-line: missing-fields
        M.kill_session(session_name, { detached = true }):start()
      end,
    })
  end
end

--- Aborts the kill process on the matching popup.
---@param opts? tmux-toggle-popup.SessionIdentifier
function M.save(opts)
  local c = config.read()
  ---@type tmux-toggle-popup.Session
  opts = vim.tbl_deep_extend("force", {}, c, opts or {})

  M.validate_session_identifier(opts)

  local session_name, id_format = M.format_identifier(opts)

  if not session_name then
    log.warn("Can not get session name for popup: %s", id_format)

    return
  end

  local id = M._.autocmd_to_kill[session_name]

  if not id then
    return
  end

  vim.api.nvim_del_autocmd(id)

  M._.autocmd_to_kill[session_name] = nil

  log.info("Saved tmux session: %s", session_name)
end

--- Aborts all the kill autocommands.
function M.save_all()
  pcall(vim.api.nvim_del_augroup_by_name, AUGROUP_TO_KILL)

  if vim.tbl_isempty(M._.autocmd_to_kill) then
    return
  end

  log.info("Saved tmux sessions: %s", table.concat(vim.tbl_keys(M._.autocmd_to_kill), ", "))

  M._.autocmd_to_kill = {}
end

--- @param opts? tmux-toggle-popup.SessionIdentifier
function M.kill(opts)
  local c = config.read()
  ---@type tmux-toggle-popup.Session
  opts = vim.tbl_deep_extend("force", {}, c, opts or {})

  M.validate_session_identifier(opts)

  local session_name, id_format = M.format_identifier(opts)

  if not session_name then
    log.warn("Can not get session name for popup: %s", id_format)

    return
  end

  ---@diagnostic disable-next-line: missing-fields
  M.kill_session(session_name, { detached = true }):start()

  M._.sessions[session_name] = nil

  log.info("Killed tmux session: %s -> %s", opts.name, session_name)
end

--- Kills all managed sessions.
function M.kill_all()
  if vim.tbl_isempty(M._.sessions) then
    return
  end

  for _, session_name in ipairs(vim.tbl_keys(M._.sessions)) do
    ---@diagnostic disable-next-line: missing-fields
    M.kill_session(session_name, { detached = true }):start()
  end

  log.info("Killed tmux sessions: %s", table.concat(vim.tbl_keys(M._.sessions), ", "))

  M._.sessions = {}
end

---@param opts tmux-toggle-popup.SessionIdentifier
---@return string?, string?
function M.format_identifier(opts)
  local id_format = utils.interpolate_id_format(opts.id_format, opts.name)
  local session_name = utils.interpolate_session_name(id_format)

  return session_name, id_format
end

---@param opts tmux-toggle-popup.Session
---@return string[]
function M.parse_flags(opts)
  local flags = {}

  if opts.flags.no_border then
    table.insert(flags, "-B")
  end

  if opts.flags.close then
    table.insert(flags, "-C")
  end

  if opts.flags.close_on_exit == "on-failure" then
    table.insert(flags, "-EE")
  elseif opts.flags.close_on_exit == true then
    table.insert(flags, "-E")
  end

  if opts.flags.border then
    vim.list_extend(flags, { "-b", opts.flags.border })
  end

  if opts.flags.target_client then
    vim.list_extend(flags, { "-c", opts.flags.target_client })
  end

  if opts.flags.start_directory then
    if type(opts.flags.start_directory) == "function" then
      opts.flags.start_directory = opts.flags.start_directory()
    end

    if opts.flags.start_directory ~= nil then
      vim.list_extend(flags, { "-d", opts.flags.start_directory })
    end
  end

  if opts.flags.popup_style then
    vim.list_extend(flags, { "-s", opts.flags.popup_style })
  end

  if opts.flags.border_style then
    vim.list_extend(flags, { "-S", opts.flags.border_style })
  end

  if opts.flags.target_pane then
    vim.list_extend(flags, { "-p", opts.flags.target_pane })
  end

  if opts.flags.title then
    if type(opts.flags.title) == "function" then
      local id_format = utils.interpolate_id_format(opts.id_format, opts.name)
      local session_name = utils.interpolate_session_name(id_format)

      if session_name then
        opts.flags.title = opts.flags.title(opts, session_name)
      end
    end

    if opts.flags.title ~= nil then
      vim.list_extend(flags, { "-T", opts.flags.title })
    end
  end

  return flags
end

---
---@param session_name string
---@param opts? Job
---@return Job
function M.kill_session(session_name, opts)
  return Job:new(vim.tbl_extend("force", opts or {}, {
    command = "tmux",
    args = {
      "kill-session",
      "-t",
      session_name,
    },
  }))
end

return M
