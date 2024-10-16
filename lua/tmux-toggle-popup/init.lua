local M = {
  setup = require("tmux-toggle-popup.config").setup,
  open = require("tmux-toggle-popup.api").open,
  save = require("tmux-toggle-popup.api").save,
  save_all = require("tmux-toggle-popup.api").save_all,
  kill = require("tmux-toggle-popup.api").kill,
  kill_all = require("tmux-toggle-popup.api").kill_all,
  format = require("tmux-toggle-popup.api").format,
  is_tmux = require("tmux-toggle-popup.utils").is_tmux,
}

return M
