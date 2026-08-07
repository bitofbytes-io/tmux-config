# tmux Configuration

This directory contains tmux configuration files and plugin data managed by [TPM](https://github.com/tmux-plugins/tpm).

## File locations

- `~/.config/tmux/tmux.conf` – primary tmux configuration used when tmux starts
- `~/.config/tmux/plugins/` – TPM-managed plugins installed from GitHub
- `~/.config/tmux/resurrect/` – session snapshots saved by `tmux-resurrect`

The `plugins/` and `resurrect/` directories are runtime data and are ignored by
Git. Install or update plugins with TPM rather than committing either directory.

## Plugins

- `tmux-plugins/tpm` – plugin manager that installs and updates all other plugins
- `tmux-plugins/tmux-sensible` – collection of sane default settings
- `christoomey/vim-tmux-navigator` – seamless movement between Vim splits and tmux panes
- `dreamsofcode-io/catppuccin-tmux` – Catppuccin themed status bar and colours
- `tmux-plugins/tmux-yank` – augments copy mode to integrate with the system clipboard
- `tmux-plugins/tmux-open` – opens highlighted URLs or file paths from copy mode
- `tmux-plugins/tmux-resurrect` – persists sessions, windows, and panes to disk
- `tmux-plugins/tmux-continuum` – automatically saves and restores sessions on interval
- `sainnhe/tmux-fzf` – interactive session, window, pane, and command selection with fzf

## Custom configuration highlights

- Advertises `tmux-256color` inside tmux and enables RGB/Tc only when the outer
  terminal is Ghostty (`xterm-ghostty`)
- Enables mouse support, OSC 52 clipboard integration, and terminal passthrough
- Sets escape latency to zero and keeps 100,000 lines of pane history
- Changes prefix from `Ctrl-b` to `Ctrl-Space`
- Windows and panes start counting at 1 and renumber automatically
- Uses vi-style copy mode keys with custom bindings for select (`v`), rectangle toggle (`Ctrl-v`), and yank (`y`)
- Split key bindings (`"` vertical, `%` horizontal) preserve the current working directory
- `Ctrl-Shift-Left` and `Ctrl-Shift-Right` swap the current window with the previous or next
- TPM path configured to `~/.config/tmux/plugins` with TPM run command updated accordingly
- tmux-yank uses vi-style shell mode
- Continuum saves every 15 minutes and restores sessions on launch, storing data
  in `~/.config/tmux/resurrect`; resurrect backup snapshots are retained for seven days

## Portability notes

The host must provide a `tmux-256color` terminfo entry. Ghostty-specific true
colour overrides remain scoped to `xterm-ghostty` and do not affect other
terminals. `set-clipboard on` uses OSC 52 when the outer terminal supports it;
`tmux-yank` additionally integrates with platform clipboard tools such as
`pbcopy`/`pbpaste` on macOS or `xclip`/`xsel` on Linux. `allow-passthrough` requires
a tmux version that supports that option.

This configuration assumes trusted programs and output inside tmux. With
`set-clipboard on`, applications can write to the outer terminal's clipboard;
with `allow-passthrough on`, a visible pane can send escape sequences directly
to the outer terminal. Set `set-clipboard` to `external` or `off` and
`allow-passthrough` to `off` before running untrusted programs or displaying
untrusted output.
