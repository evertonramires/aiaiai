#!/bin/sh
# Install aiaiai: symlink it onto your PATH (default ~/.local/bin), add the
# short alias "ai", then walk you through pointing it at an AI.
#
#   ./install.sh [target-dir]
#
#   NO_SHORT_ALIAS=1   skip the "ai" alias
#   NO_SETUP=1         skip the interactive configuration
set -eu

src="$(cd "$(dirname "$0")" && pwd)/aiaiai"
dest="${1:-$HOME/.local/bin}"

# --- python 3.11+ is the only dependency -----------------------------------
python="$(command -v python3 || true)"
if [ -z "$python" ]; then
  echo "aiaiai needs Python 3.11 or newer, and python3 was not found." >&2
  echo "  macOS:         brew install python" >&2
  echo "  Debian/Ubuntu: sudo apt install python3" >&2
  echo "  Fedora:        sudo dnf install python3" >&2
  exit 1
fi
if ! "$python" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)'; then
  echo "aiaiai needs Python 3.11 or newer, but $python is $("$python" -V 2>&1)." >&2
  echo "  Debian/Ubuntu: sudo apt install python3.11" >&2
  echo "  Fedora:        sudo dnf install python3.11" >&2
  echo "  macOS:         brew install python" >&2
  exit 1
fi

# --- links -----------------------------------------------------------------
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
  *)
    echo
    echo "note: $dest is not on your PATH. Add this to your shell rc file:"
    echo "      export PATH=\"\$PATH:$dest\""
    ;;
esac

# --- configuration ---------------------------------------------------------
if [ "${NO_SETUP:-0}" = "1" ]; then
  echo "skipping configuration (NO_SETUP=1). Run 'aiaiai --setup' when ready."
  exit 0
fi
if [ ! -t 0 ]; then
  echo "no terminal here, so skipping configuration."
  echo "Run 'aiaiai --setup' to finish."
  exit 0
fi

echo
"$dest/aiaiai" --setup
