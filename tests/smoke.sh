#!/bin/sh
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
config=${1:-"$root/tmux.conf"}
scratch=$(mktemp -d)
export HOME="$scratch/home" XDG_CONFIG_HOME="$scratch/home/.config"
unset TMUX TMUX_PLUGIN_MANAGER_PATH
mkdir -p "$HOME"
socket="$scratch/socket"
cleanup() {
  tmux -S "$socket" kill-server 2>/dev/null || true
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM
# Keep the server alive, always address our own socket, and never read user config.
tmux -S "$socket" -f /dev/null new-session -d -s smoke 'sleep 3600'
tmux -S "$socket" source-file -n "$config"
tmux -S "$socket" source-file "$config"
[ "$(tmux -S "$socket" show-option -gv prefix)" = C-Space ]
[ "$(tmux -S "$socket" show-option -gv mouse)" = on ]
[ "$(tmux -S "$socket" show-option -gv base-index)" = 1 ]
[ "$(tmux -S "$socket" show-option -gv allow-passthrough)" = on ]
[ "$(tmux -S "$socket" show-option -gv history-limit)" = 100000 ]
tmux -S "$socket" list-keys -T prefix > "$scratch/keys"
grep -Eq 'prefix +C-x +.*synchronize-panes' "$scratch/keys"
grep -Fq 'split-window -v -c' "$scratch/keys"
grep -Fq 'split-window -h -c' "$scratch/keys"
for key in I U; do
  grep -E "prefix +$key +" "$scratch/keys" | grep -q scripts/install-plugins.sh
done
[ ! -d "$HOME/.config/tmux/plugins" ]
printf '%s\n' "$(tmux -V): isolated parse and source tests passed without TPM."
