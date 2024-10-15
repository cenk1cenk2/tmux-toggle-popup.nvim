local M = {
  _ = {
    kill_autocmd = {},
  },
}

local config = require("tmux-toggle-popup.config")
local log = require("tmux-toggle-popup.log")
local utils = require("tmux-toggle-popup.utils")

local AUGROUP_KILL = "tmux-toggle-popup-kill"

---@class tmux-toggle-popup.ToggleOpts: tmux-toggle-popup.ConfigUiSize, tmux-toggle-popup.PopupIdentifier
---@field socket_name string?
---@field flags string[]?
---@field command string[]?
---@field env table<string, string>?
---@field on_init string[]?
---@field before_open string[]?
---@field after_close string[]?
---@field kill boolean?

---@class tmux-toggle-popup.PopupIdentifier
---@field name string?
---@field id_format string?

---@param opts tmux-toggle-popup.ToggleOpts
function M.validate(opts)
  vim.validate({
    name = { opts.name, "string", true },
    socket_name = { opts.socket_name, "string", true },
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

---@param opts? tmux-toggle-popup.ToggleOpts
function M.toggle(opts)
  local c = config.read()
  ---@type tmux-toggle-popup.ToggleOpts
  opts = vim.tbl_deep_extend("force", {}, c, opts or {})

  M.validate(opts)

  local ui = require("tmux-toggle-popup.utils").calculate_ui(opts)

  if not require("tmux-toggle-popup.utils").is_tmux() then
    log.error("Not running inside tmux, aborting.")

    return
  end

  opts.id_format = utils.escape_id_format(opts.id_format)

  local args = {
    "--single-instance",
    "--name",
    opts.name,
    "--socket-name",
    opts.socket_name,
    "--id-format",
    opts.id_format,
    "-E",
    ("-d %s"):format(vim.uv.cwd()),
    ("-w %s%%"):format(ui.width),
    ("-h %s%%"):format(ui.height),
  }

  local sockets = vim.fn.serverlist()
  if sockets and #sockets > 0 then
    opts.env["NVIM"] = sockets[1]
  end

  for key, value in pairs(opts.env) do
    table.insert(opts.flags, "-e " .. key .. "=" .. value)
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

  if opts.flags and #opts.flags > 0 then
    table.insert(args, table.concat(opts.flags, " "))
  end

  if opts.command then
    vim.list_extend(args, opts.command)
  end

  log.debug("Trying to spawn a new tmux command with: %s", args)
  require("plenary.job")
    :new({
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
    })
    :start()

  if opts.kill then
    local id_format = utils.interpolate_id_format(opts.id_format, opts.name)
    local session_name = utils.interpolate_session_name(id_format)

    if not session_name then
      log.warn("Can not get session name for popup: %s", id_format)

      return
    end

    M._.kill_autocmd[session_name] = vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
      group = vim.api.nvim_create_augroup(AUGROUP_KILL, { clear = false }),
      pattern = "*",
      callback = function()
        vim.system({
          "tmux",
          "kill-session",
          "-t",
          session_name,
        }, {
          detach = true,
        })
      end,
    })
  end
end

--- Aborts the kill process on the matching popup.
---@param opts? tmux-toggle-popup.PopupIdentifier
function M.save_session(opts)
  local c = config.read()
  ---@type tmux-toggle-popup.ToggleOpts
  opts = vim.tbl_deep_extend("force", {}, c, opts or {})

  vim.validate({
    name = { opts.name, "string", true },
    id_format = { opts.id_format, "string", true },
  })

  local id_format = utils.interpolate_id_format(opts.id_format, opts.name)
  local session_name = utils.interpolate_session_name(id_format)

  if not session_name then
    log.warn("Can not get session name for popup: %s", id_format)

    return
  end

  local id = M._.kill_autocmd[session_name]

  if not id then
    return
  end

  vim.api.nvim_del_autocmd(id)

  M._.kill_autocmd[session_name] = nil

  log.info("Saved tmux session: %s", session_name)
end

--- Aborts all the kill autocommands.
function M.save_all()
  pcall(vim.api.nvim_del_augroup_by_name, AUGROUP_KILL)

  if vim.tbl_isempty(M._.kill_autocmd) then
    return
  end

  log.info("Saved tmux sessions: %s", table.concat(vim.tbl_keys(M._.kill_autocmd), ", "))

  M._.kill_autocmd = {}
end

return M
