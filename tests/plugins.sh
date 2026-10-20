#!/bin/sh
# Network integration test: installs real pinned upstream repositories in a temp HOME.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d)
socket="$scratch/socket"
cleanup() {
  tmux -S "$socket" kill-server 2>/dev/null || true
  rm -rf "$scratch"
}
trap cleanup EXIT HUP INT TERM
export HOME="$scratch/home" XDG_CONFIG_HOME="$scratch/home/.config"
unset TMUX TMUX_PLUGIN_MANAGER_PATH
sh "$root/scripts/install-plugins.sh"
sh "$root/scripts/install-plugins.sh"
while read -r repository revision version; do
  case "$repository" in ''|'#'*) continue ;; esac
  target="$HOME/.config/tmux/plugins/${repository##*/}"
  [ "$(git -C "$target" rev-parse HEAD)" = "$revision" ]
  [ "$(git -C "$target" remote get-url origin)" = "https://github.com/$repository.git" ]
  if git -C "$target" symbolic-ref -q HEAD; then
    echo "Expected detached HEAD: $repository ($version)" >&2
    exit 1
  fi
  grep -Fq "@plugin '$repository#$revision'" "$root/tmux.conf"
done < "$root/plugins.lock"
# Exercise TPM loading and ensure its defaults cannot replace the pinned bindings.
cp "$root/tmux.conf" "$HOME/.config/tmux/tmux.conf"
mkdir -p "$HOME/.config/tmux/scripts"
cp "$root/scripts/install-plugins.sh" "$HOME/.config/tmux/scripts/"
cp "$root/plugins.lock" "$HOME/.config/tmux/"
printf '\nset -g @binding-reloaded complete\n' >> "$HOME/.config/tmux/tmux.conf"
tmux -S "$socket" -f /dev/null new-session -d -s plugins 'sleep 3600'
tmux -S "$socket" source-file "$HOME/.config/tmux/tmux.conf"
tmux -S "$socket" list-keys -T prefix > "$scratch/keys"
for key in I U; do
  grep -E "prefix +$key +" "$scratch/keys" | grep -q scripts/install-plugins.sh
  # Replay the actual key's action without requiring an interactive client.
  sed -n "s/^bind-key[[:space:]]*-T prefix[[:space:]]*${key}[[:space:]]*//p" "$scratch/keys" > "$scratch/binding.conf"
  [ -s "$scratch/binding.conf" ]
  tmux -S "$socket" set-option -g @binding-reloaded pending
  tmux -S "$socket" source-file "$scratch/binding.conf"
  [ "$(tmux -S "$socket" show-option -gv @binding-reloaded)" = complete ]
done
grep -E 'prefix +p +' "$scratch/keys" | grep -q floax.sh
grep -E 'prefix +P +' "$scratch/keys" | grep -q menu.sh
grep -E 'prefix +t +' "$scratch/keys" | grep -q tmux-thumbs.sh
target="$HOME/.config/tmux/plugins/tpm"
sh "$root/tests/concurrency.sh" "$target"
printf '%s\n' 'local change' >> "$target/README.md"
if sh "$root/scripts/install-plugins.sh" >"$scratch/log" 2>&1; then
  echo 'Installer accepted a dirty checkout' >&2
  exit 1
fi
grep -q 'Refusing dirty plugin' "$scratch/log"
grep -q 'local change' "$target/README.md"
git -C "$target" restore README.md
git -C "$target" remote set-url origin https://example.invalid/wrong.git
if sh "$root/scripts/install-plugins.sh" >"$scratch/log" 2>&1; then
  echo 'Installer accepted an unexpected origin' >&2
  exit 1
fi
grep -q 'Unexpected origin' "$scratch/log"
mv "$target" "$scratch/tpm-checkout"
mkdir "$target"
if sh "$root/scripts/install-plugins.sh" >"$scratch/log" 2>&1; then
  echo 'Installer accepted a non-checkout directory' >&2
  exit 1
fi
grep -q 'Not a standalone checkout' "$scratch/log"
rmdir "$target"
ln -s "$scratch/tpm-checkout" "$target"
if sh "$root/scripts/install-plugins.sh" >"$scratch/log" 2>&1; then
  echo 'Installer accepted a symlink to a checkout' >&2
  exit 1
fi
grep -q 'Not a standalone checkout' "$scratch/log"
printf '%s\n' 'Pinned install, repeat install, exact HEADs, plugin bindings, dirty/origin refusal, and non-checkout/symlink refusal passed.'
