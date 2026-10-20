#!/bin/sh
# Install only the reviewed commits in this checkout's manifest.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
plugins="$HOME/.config/tmux/plugins"
staging=
cleanup() { [ -z "$staging" ] || rm -rf "$staging"; }
trap cleanup EXIT HUP INT TERM
fail() { printf '%s\n' "$*" >&2; exit 1; }

# Preflight every existing checkout before changing any of them.
while read -r repository revision version; do
  case "$repository" in ''|'#'*) continue ;; esac
  case "$repository" in *[!a-zA-Z0-9_./-]*|../*|*/../*|/*) fail 'Invalid repository in plugins.lock' ;; esac
  [ "${#revision}" = 40 ] || fail "Invalid revision for $repository"
  case "$revision" in *[!0-9a-f]*) fail "Invalid revision for $repository" ;; esac
  target="$plugins/${repository##*/}"
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ -L "$target" ] || [ ! -d "$target/.git" ]; then
      fail "Not a standalone checkout: $target"
    fi
    [ "$(git -C "$target" remote get-url origin)" = "https://github.com/$repository.git" ] || fail "Unexpected origin: $target"
    [ -z "$(git -C "$target" status --porcelain --untracked-files=all)" ] || fail "Refusing dirty plugin: $target"
  fi
done < "$root/plugins.lock"

mkdir -p "$plugins"
while read -r repository revision version; do
  case "$repository" in ''|'#'*) continue ;; esac
  target="$plugins/${repository##*/}"
  if [ ! -d "$target" ]; then
    staging=$(mktemp -d "$plugins/.install.XXXXXX")
    git -C "$staging" init -q
    git -C "$staging" remote add origin "https://github.com/$repository.git"
    git -C "$staging" fetch -q --depth 1 origin "$revision"
    git -C "$staging" checkout -q --detach "$revision"
    [ "$(git -C "$staging" rev-parse HEAD)" = "$revision" ] || fail "Revision mismatch: $repository"
    mv "$staging" "$target"
    staging=
  else
    if ! git -C "$target" cat-file -e "$revision^{commit}" 2>/dev/null; then
      git -C "$target" fetch -q --depth 1 origin "$revision"
    fi
    git -C "$target" checkout -q --detach "$revision"
  fi
  [ "$(git -C "$target" rev-parse HEAD)" = "$revision" ] || fail "Revision mismatch: $repository"
  printf '%s %s (%s)\n' "$repository" "$revision" "$version"
done < "$root/plugins.lock"
