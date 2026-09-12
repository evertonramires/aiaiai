#!/bin/sh
# Symlink aiaiai into a directory on PATH (default ~/.local/bin), plus the
# short alias "ai". Pass a directory to install somewhere else, and set
# NO_SHORT_ALIAS=1 to skip the "ai" link.
set -eu
src="$(cd "$(dirname "$0")" && pwd)/aiaiai"
dest="${1:-$HOME/.local/bin}"
mkdir -p "$dest"
chmod +x "$src"

ln -sf "$src" "$dest/aiaiai"
echo "linked $dest/aiaiai -> $src"

if [ "${NO_SHORT_ALIAS:-0}" = "1" ]; then
  echo "skipping the short 'ai' alias (NO_SHORT_ALIAS=1)"
else
  existing="$(command -v ai 2>/dev/null || true)"
  if [ -n "$existing" ] && [ "$existing" != "$dest/ai" ] && [ ! -L "$dest/ai" ]; then
    echo "note: 'ai' is already $existing - not touching it"
    echo "      re-run with NO_SHORT_ALIAS=1 to silence this"
  else
    ln -sf "$src" "$dest/ai"
    echo "linked $dest/ai -> $src"
  fi
fi

case ":$PATH:" in
  *":$dest:"*) ;;
  *) echo "note: $dest is not on your PATH" ;;
esac
echo "next: aiaiai --init"
