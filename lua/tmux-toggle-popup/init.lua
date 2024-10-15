local M = {
  setup = require("tmux-toggle-popup.config").setup,
  toggle = require("tmux-toggle-popup.api").toggle,
  save_all = require("tmux-toggle-popup.api").save_all,
  save_session = require("tmux-toggle-popup.api").save_session,
}

return M
