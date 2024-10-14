local M = {
  _ = {},
}

local config = require("tmux-toggle-popup.config")
local log = require("tmux-toggle-popup.log")

---@class tmux-toggle-popup.ToggleOpts: tmux-toggle-popup.ConfigUiSize
---@field name string
---@field socket_name string?
---@field id_format string?
---@field command string?
---@field on_init string[]?
---@field kill_on_vim_leave boolean?

---@type fun(opts?: tmux-toggle-popup.ToggleOpts): nil
function M.toggle(opts)
  local c = config.read()
  opts = vim.tbl_deep_extend("force", {}, c, opts or {})

  local ui = require("tmux-toggle-popup.utils").calculate_ui(opts)

  if not require("tmux-toggle-popup.utils").is_tmux() then
    log.error("Not running inside tmux, aborting.")

    return
  end

  local args = {
    "--name",
    opts.name,
    "--socket-name",
    opts.socket_name,
    "--id-format",
    opts.id_format,
    ("-Ed%s"):format(vim.uv.cwd()),
    ("-w%s%%"):format(ui.width),
    ("-h%s%%"):format(ui.height),
  }

  table.insert(args, "--on-init")
  local on_init = { ("setenv NVIM %s"):format(vim.env["NVIM"]) }
  if opts.on_init then
    vim.list_extend(on_init, opts.on_init)
  end
  table.insert(args, table.concat(on_init, [[\; ]]))

  if opts.command then
    table.insert(args, opts.command)
  end

  log.debug("Trying to spawn a new tmux command with: %s %s", config.state.script, vim.fn.join(args, " "))
  require("plenary.job")
    :new({
      command = config.state.script,
      args = args,
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

  if opts.kill_on_vim_leave then
    vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
      group = vim.api.nvim_create_augroup("tmux-toggle-popup", { clear = false }),
      pattern = "*",
      callback = function()
        -- local session_name = require("plenary.job")
        --   :new({
        --     command = "tmux",
        --     args = vim.fn.split(("set %s %s\\; display -p @popup-name\\; set -u %s\\;"):format(opts.name, opts.id_format), " "),
        --   })
        --   :sync(1000)
        --
        -- if not session_name or #session_name == 0 then
        --   log.error("Can not get session name for %s", opts.name)
        --
        --   return
        -- end
        --
        -- log.debug("Got session name: %s -> %s", opts.name, session_name)
        --
        -- require("plenary.job")
        --   :new({
        --     command = "tmux",
        --     args = {
        --       "kill-session",
        --       "-t",
        --       vim.fn.join(session_name, ""),
        --     },
        --     on_exit = function(j, code)
        --       if code > 0 then
        --         log.debug("Can not kill tmux session: %s", j:stderr_result())
        --
        --         return
        --       end
        --
        --       log.debug("Killed tmux session: %s -> %s", opts.name, session_name)
        --     end,
        --   })
        --   :sync(1000)
      end,
    })
  end
end

return M
