# tmux-toggle-popup.nvim

This plugin wraps around the [`tmux-toggle-popup`](https://github.com/loichyan/tmux-toggle-popup) plugin to provide a interface to create `tmux` popup windows in `neovim`.

All credits go to the [@loichyan](https://github.com/loichyan) for building this amazing flow of `tmux` popup windows.

## Disclaimer

Currently this plugin is in the dogfooding stage and evaluated for feasbility.

## Features

- Ability to open up `tmux` popup windows in `neovim`. ![demo](./media/2024-10-16T13:51:27,126834947+02:00.png) ![demo](./media/2024-10-16T13:54:51,640423671+02:00.png)
- Being able to have the power of the `tmux` that is strictly bound to the `neovim` instance.
- A choice between saving and killing your ongoing windows on `neovim` exit.
- Seamless integration with [willothy/flatten.nvim](https://github.com/willothy/flatten.nvim) so that the open command you execute on your terminals will be opened in your `neovim` instance. ![demo](./media/2024-10-16T13:52:19,582768219+02:00.png)

## Installation

Since this plugin directly wraps around the original tmux plugin [`tmux-toggle-popup`](https://github.com/loichyan/tmux-toggle-popup) please follow the installation instructions there to enable it for `tmux`.

An example for this would be in your `tmux.conf` file is as follows.

```tmux
# install with tpm
set -g @plugin "loichyan/tmux-toggle-popup"

# I am binding my leader C-a to open up a popup window in the tmux configuration.
# This same keybinding from tmux will be also used to close up any open popup window with `--single-instance` flag.
bind C-a run "#{@popup-toggle} --single-instance --name scratch -Ed'#{pane_current_path}' -w98% -h98%"

# install tmux plugins
if "test ! -d ~/.config/tmux/plugins/tpm" \
   "run 'git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm && ~/.config/tmux/plugins/tpm/bin/install_plugins'"

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.config/tmux/plugins/tpm/tpm'
```

### `lazy.nvim`

```lua
{
  "cenk1cenk2/tmux-toggle-popup.nvim",
  dependencies = {
    -- https://github.com/nvim-lua/plenary.nvim
    "nvim-lua/plenary.nvim",
  },
}
```

## Configuration

### Setup

```lua
require("tmux-toggle-popup").setup()
```

You can find the default configuration file and available options [here](https://github.com/cenk1cenk2/tmux-toggle-popup.nvim/blob/main/lua/tmux-toggle-popup/config.lua).

The configuration format looks like follows and adjust either the `tmux` plugin variables or the `tmux` popup variables.

#### Session Defaults

```lua
---@class tmux-toggle-popup.Session: tmux-toggle-popup.ConfigUiSize, tmux-toggle-popup.SessionIdentifier
---@field socket_name string? --- Socket name for the TMUX session, you can give this if you want to isolate your popup to a specific session.
---@field command string[]? --- The starting command for the popup, will use the default tmux command if not given.
---@field env table<string, string>? --- Environment variables that are going to be passed to the popup.
---@field on_init string[]? --- Tmux commands that are going to be run insdie the popup after being created.
---@field before_open string[]? --- Tmux commands that are going to be run on the main session the popup is opened.
---@field after_close string[]? --- Tmux commands that are going to be run on the main session the popup is closed.
---@field kill boolean? --- Kill the session, on `VimLeavePre` event.
---@field flags tmux-toggle-popup.Flags? --- Flags for passing in the tmux popup command.

-- The flags does reside in the .flags table.

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

---@class tmux-toggle-popup.ConfigUiSize
---@field width? number | (fun(columns: number): number?) --- calculate the width of the popup from the terminal columns
---@field height? number | (fun(lines: number): number?) --- calculate the height of the popup from the terminal lines

```

#### Plugin Options

```lua
---@field log_level? number --- Adjusts the log level for the plugin.
```

## Usage

The plugin can be used via by opening up a popup window with a specific command.

Bind this actions to any keybinding or commands you like to interact with them.

### Create a Session

```lua
require("tmux-toggle-popup").open()
```

**Since `tmux` popup will steal the focus from `neovim` you have to use your global keybinding that is set for the `tmux` plugin.**

So imagine that you have mapped this popup to `<F1>` on your `neovim` instance and you have set the `tmux` popup to `leader<C-a>` on your `tmux` configuration as describe above. I can open up a `neovim` popup for my terminal with `<F1>`, however since `tmux` popup window will steal the focus, you can close it with your global `tmux` binding of `leader<C-a>`

You can pass any of the session options as a argument to the `open` function.

An example to this might be a keybind to toggle `lazygit`.

```lua
require("tmux-toggle-popup").open({ name = "lazygit", command = { "lazygit" }, on_init = { "set status off" } })
```

### Save Your Session

The `kill` option in the session configuration will kill the session on `VimLeavePre` event.

However you can save your current session, if `kill` is set to `true` by calling the following function.

```lua
require("tmux-toggle-popup").save()
```

This also takes in the same session options as the `open` function. So you can save a specific session with a specific name.

```lua
require("tmux-toggle-popup").save({ name = "lazygit" })
```

You can also save everything in the current session.

```lua
require("tmux-toggle-popup").save_all()
```

### Kill Your Session

You can kill your session with the following function.

```lua
require("tmux-toggle-popup").kill()
```

This also takes in the same session options as the `open` function. So you can kill a specific session with a specific name.

```lua
require("tmux-toggle-popup").kill({ name = "lazygit" })
```

You can also kill everything in the current session.

```lua
require("tmux-toggle-popup").kill_all()
```
