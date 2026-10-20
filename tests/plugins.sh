#!/bin/sh
# Network integration test: installs real pinned upstream repositories in a temp HOME.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d)
socket="$scratch/socket"
phase='installing and checking pinned plugins'
cleanup() {
  result=$?
  if [ "$result" -ne 0 ]; then
    printf 'Plugin integration failed during %s (exit %s)\n' "$phase" "$result" >&2
    tmux -V >&2
    tmux -S "$socket" show-messages >&2 2>/dev/null || true
  fi
  tmux -S "$socket" kill-server 2>/dev/null || true
  rm -rf "$scratch"
  exit "$result"
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
phase='starting tmux and loading plugins'
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
done
phase='executing prefix + I/U and checking reload completion'
python3 "$root/tests/bindings.py" "$socket"
phase='checking plugin bindings and installer guards'
grep -E 'prefix +p +' "$scratch/keys" | grep -q floax.sh
grep -E 'prefix +P +' "$scratch/keys" | grep -q menu.sh
grep -E 'prefix +t +' "$scratch/keys" | grep -q tmux-thumbs.sh
target="$HOME/.config/tmux/plugins/tpm"
sh "$root/tests/concurrency.sh" "$target"
revision=$(git -C "$target" rev-parse HEAD)
for origin in https://github.com/tmux-plugins/tpm \
  https://git::@github.com/tmux-plugins/tpm \
  https://git::@github.com/tmux-plugins/tpm.git; do
  git -C "$target" remote set-url origin "$origin"
  sh "$root/scripts/install-plugins.sh" > "$scratch/log" 2>&1
  [ "$(git -C "$target" rev-parse HEAD)" = "$revision" ]
  [ "$(git -C "$target" remote get-url origin)" = "$origin" ]
done
printf '%s\n' 'local change' >> "$target/README.md"
if sh "$root/scripts/install-plugins.sh" >"$scratch/log" 2>&1; then
  echo 'Installer accepted a dirty checkout' >&2
  exit 1
fi
grep -q 'Refusing dirty plugin' "$scratch/log"
grep -q 'local change' "$target/README.md"
git -C "$target" restore README.md
for origin in https://example.invalid/wrong.git \
  https://github.com/other-owner/tpm.git \
  https://github.com.example.invalid/tmux-plugins/tpm.git \
  https://unexpected:credential@github.com/tmux-plugins/tpm.git; do
  git -C "$target" remote set-url origin "$origin"
  if sh "$root/scripts/install-plugins.sh" >"$scratch/log" 2>&1; then
    echo 'Installer accepted an unexpected origin' >&2
    exit 1
  fi
  grep -q 'Unexpected origin' "$scratch/log"
done
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
