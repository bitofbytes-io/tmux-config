# tmux Configuration

This repository contains a tmux configuration and an exact-commit plugin manifest.
[TPM](https://github.com/tmux-plugins/tpm) loads the installed plugins; the bundled
installer keeps their versions reproducible.

## File locations

- `~/.config/tmux/tmux.conf` – primary tmux configuration used when tmux starts
- `~/.config/tmux/plugins/` – pinned plugins installed from GitHub
- `~/.config/tmux/resurrect/` – session snapshots saved by `tmux-resurrect`

The `plugins/` and `resurrect/` directories are runtime data and are ignored by
Git. Install or update plugins using the pinned bootstrap below.

## Installation

Requires **tmux 3.3a or newer**, Git, a POSIX shell, Bash (used by plugins), and
network access to GitHub. The terminal must provide `tmux-256color` terminfo.
Install `fzf` for tmux-fzf and a platform clipboard tool for tmux-yank (see below).
The pinned tmux-thumbs release offers a first-use helper installer. Choose
**Compile** (requires Rust/Cargo) to build its pinned source; its **Download**
option fetches a floating latest release and is outside this pin guarantee.
The bootstrap here fetches plugin source only. FloaX uses tmux popups.

If `~/.config/tmux` already exists, back it up or use its existing checkout;
do not clone over it. An existing `~/.tmux.conf` takes precedence over the XDG
configuration, so back that up too or explicitly launch with the `-f` below.

```sh
mkdir -p "$HOME/.config"
git clone https://github.com/bitofbytes-io/tmux-config.git "$HOME/.config/tmux"
sh "$HOME/.config/tmux/scripts/install-plugins.sh"
tmux -f "$HOME/.config/tmux/tmux.conf"
```

The configuration also starts cleanly before bootstrap, with core settings and
bindings available. The installer fetches all 11 exact commits in `plugins.lock`,
including TPM itself, verifies origin URLs and HEADs, and leaves detached checkouts.
It refuses dirty or unexpected plugin directories without overwriting local work.
For an existing SSH-origin installation, preserve it separately before bootstrap;
the expected origins are the manifest's GitHub HTTPS URLs.

After `git -C "$HOME/.config/tmux" pull --ff-only`, press **Ctrl-Space, then I**
or **Ctrl-Space, then U** to install the reviewed manifest and reload the config.
Both keys deliberately run the pinned installer. Stock TPM uses `git clone -b`
and `git pull`, which cannot reliably install raw SHA refs or update detached
checkouts. Do not invoke its install/update scripts directly. From a shell, run
the installer again and then `tmux source-file "$HOME/.config/tmux/tmux.conf"`
in the intended server. Restart tmux after plugin updates if a plugin needs it.

## Plugins

Every `@plugin` declaration includes the full commit from `plugins.lock`. To
update a plugin, review its upstream changes, update both files and this table,
and run the tests. Tags below describe the selected commits; installation always
uses the immutable SHA. The three untagged plugins use upstream commits verified
on 2026-10-20.

| Plugin | Upstream version | Exact commit |
| --- | --- | --- |
| [tmux-plugins/tpm](https://github.com/tmux-plugins/tpm) | v3.1.0 | `7bdb7ca33c9cc6440a600202b50142f401b6fe21` |
| [tmux-plugins/tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | v3.0.0 | `2ce7679f9dcf42dffa60abd59a3405b87cb8213b` |
| [christoomey/vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) | v1.0 | `85b8e5f60c1690cde57dbb66467ce39cd1b63343` |
| [dreamsofcode-io/catppuccin-tmux](https://github.com/dreamsofcode-io/catppuccin-tmux) | commit | `b4e0715356f820fc72ea8e8baf34f0f60e891718` |
| [tmux-plugins/tmux-yank](https://github.com/tmux-plugins/tmux-yank) | v2.3.0 | `fd8000238b324005389076486a2e6e03dba1c64f` |
| [tmux-plugins/tmux-open](https://github.com/tmux-plugins/tmux-open) | v3.0.0 | `f99d3189c445188eae5fa9bfeabc95df16deca92` |
| [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | v4.0.0 | `e87d7d592cac97fa38c12395ebec042c154a1844` |
| [tmux-plugins/tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) | v3.1.0 | `46e0e0023476018ddb4cc0d44783eede27e5a8ec` |
| [sainnhe/tmux-fzf](https://github.com/sainnhe/tmux-fzf) | commit | `2839d6bd0e13b7c5e385e131e4c217917fa73555` |
| [omerxx/tmux-floax](https://github.com/omerxx/tmux-floax) | commit | `133f526793d90d2caa323c47687dd5544a2c704b` |
| [fcsonline/tmux-thumbs](https://github.com/fcsonline/tmux-thumbs) | 0.8.0 | `5fdab4dbc1493fbc2a82f3e09ac9b2483bd278c3` |

## Custom configuration highlights

- Advertises `tmux-256color` inside tmux and enables RGB/Tc only when the outer
  terminal is Ghostty (`xterm-ghostty`)
- Enables mouse support, OSC 52 clipboard integration, and terminal passthrough
- Sets escape latency to zero and keeps 100,000 lines of pane history
- Changes prefix from `Ctrl-b` to `Ctrl-Space`
- Windows and panes start counting at 1 and renumber automatically
- Uses vi-style copy mode keys with custom bindings for select (`v`), rectangle toggle (`Ctrl-v`), and yank (`y`)
- Prefix + `"` stacks panes top and bottom (`split-window -v`); prefix + `%`
  places them side by side (`split-window -h`). Both preserve the current directory.
- Prefix + `Ctrl-x` toggles synchronized input: when on, typing goes to every pane
  in the window. The binding displays whether synchronization is on or off.
- Prefix + `p` toggles FloaX; prefix + `P` opens its menu (defaults in the pinned
  [`floax.tmux`](https://github.com/omerxx/tmux-floax/blob/133f526793d90d2caa323c47687dd5544a2c704b/floax.tmux)).
- `Ctrl-Shift-Left` and `Ctrl-Shift-Right` swap the current window with the previous or next
- `Ctrl-Space`, then `t` launches tmux-thumbs; `Ctrl-Space`, then `Space` cycles layouts
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
tmux 3.3 or newer; this configuration supports **3.3a and newer**.
CI parses and sources the configuration without TPM on both 3.3a and Ubuntu's
current package. Older versions are unsupported.

This configuration assumes trusted programs and output inside tmux. With
`set-clipboard on`, applications can write to the outer terminal's clipboard;
with `allow-passthrough on`, a visible pane can send escape sequences directly
to the outer terminal. Set `set-clipboard` to `external` or `off` and
`allow-passthrough` to `off` before running untrusted programs or displaying
untrusted output.

## Validation

```sh
sh tests/smoke.sh
shellcheck scripts/*.sh tests/*.sh
sh tests/plugins.sh  # network access; temporary plugin installation
```

The smoke test uses a temporary HOME, unsets `TMUX`, and creates a private socket.
It parses and actually sources the configuration without TPM, asserts options
and representative key bindings, and kills only its own server on exit. The
plugin integration test verifies exact detached HEADs, repeat installation,
manifest/config agreement, installed TPM/FloaX/thumbs bindings, and refusal of dirty checkouts or unexpected origins.
Neither test changes your personal configuration or running tmux servers.
