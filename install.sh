#!/bin/sh
# Symlink aiaiai into a directory on PATH (default ~/.local/bin).
set -eu
src="$(cd "$(dirname "$0")" && pwd)/aiaiai"
dest="${1:-$HOME/.local/bin}"
mkdir -p "$dest"
ln -sf "$src" "$dest/aiaiai"
chmod +x "$src"
echo "linked $dest/aiaiai -> $src"
case ":$PATH:" in
  *":$dest:"*) ;;
  *) echo "note: $dest is not on your PATH" ;;
esac
echo "next: aiaiai --init"
