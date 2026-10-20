#!/bin/sh
# Use an already-installed TPM checkout as a local fetch source: no network.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
CONCURRENCY_SOURCE=$1
REAL_GIT=$(command -v git)
scratch=$(mktemp -d)
winner=
cleanup() {
  touch "$scratch/release"
  if [ -n "$winner" ]; then wait "$winner" || true; fi
  rm -rf "$scratch"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
export HOME="$scratch/home" CONCURRENCY_SOURCE REAL_GIT
CONCURRENCY_GATE=$scratch
export CONCURRENCY_GATE
mkdir -p "$scratch/config/scripts" "$scratch/bin"
cp "$root/scripts/install-plugins.sh" "$scratch/config/scripts/"
awk '$1 !~ /^#/ && NF { print; exit }' "$root/plugins.lock" > "$scratch/config/plugins.lock"
CONCURRENCY_REVISION=$(awk '{ print $2 }' "$scratch/config/plugins.lock")
export CONCURRENCY_REVISION
cat > "$scratch/bin/git" <<'GIT'
#!/bin/sh
set -eu
if [ "$3" = init ]; then
  "$REAL_GIT" "$@"
  if mkdir "$CONCURRENCY_GATE/entered" 2>/dev/null; then
    # Pause the first installer before its first fetch/publication.
    attempts=0
    while [ ! -f "$CONCURRENCY_GATE/release" ]; do
      attempts=$((attempts + 1))
      [ "$attempts" -le 100 ] || exit 1
      sleep 0.1
    done
  fi
  exit 0
fi
if [ "$3" = fetch ]; then
  exec "$REAL_GIT" -C "$2" fetch -q --depth 1 "$CONCURRENCY_SOURCE" "$CONCURRENCY_REVISION"
fi
exec "$REAL_GIT" "$@"
GIT
chmod +x "$scratch/bin/git"
PATH="$scratch/bin:$PATH"
export PATH
sh "$scratch/config/scripts/install-plugins.sh" > "$scratch/winner.log" 2>&1 &
winner=$!
attempts=0
while [ ! -d "$scratch/entered" ]; do
  attempts=$((attempts + 1))
  [ "$attempts" -le 100 ] || { cat "$scratch/winner.log"; exit 1; }
  sleep 0.1
done
if sh "$scratch/config/scripts/install-plugins.sh" > "$scratch/contender.log" 2>&1; then
  echo 'Concurrent installer was accepted while publication was paused' >&2
  exit 1
fi
grep -q 'Another plugin install may be running' "$scratch/contender.log"
# A rejected contender must not release the winner's lock.
[ -d "$HOME/.config/tmux/plugins/.install.lock" ]
touch "$scratch/release"
if ! wait "$winner"; then cat "$scratch/winner.log"; exit 1; fi
winner=
target="$HOME/.config/tmux/plugins/tpm"
[ "$(git -C "$target" rev-parse HEAD)" = "$CONCURRENCY_REVISION" ]
[ ! -e "$HOME/.config/tmux/plugins/.install.lock" ]
for nested in "$target"/.install.*; do
  [ ! -e "$nested" ] || { echo 'Nested staging checkout found' >&2; exit 1; }
done
# Completion releases the lock, allowing an ordinary subsequent install.
sh "$scratch/config/scripts/install-plugins.sh" > "$scratch/repeat.log" 2>&1
printf '%s\n' 'Concurrent installer refused; winner published one exact checkout and released its lock.'
