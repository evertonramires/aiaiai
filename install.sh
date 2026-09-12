#!/bin/sh
# aiaiai installer for Linux and macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/evertonramires/aiaiai/main/install.sh | sh
#
# or, from a clone:   ./install.sh [target-dir]
#
# It finds or installs Python 3.11+, puts aiaiai (and the short alias ai) on
# your PATH, and walks you through pointing it at an AI.
#
#   NO_SHORT_ALIAS=1  skip the "ai" alias
#   NO_SETUP=1        skip the interactive configuration
#   NO_PATH_EDIT=1    do not touch your shell rc file
#
# Copyright (C) 2026 aiaiai contributors. AGPL-3.0-or-later.
set -eu

REPO_RAW="${AIAIAI_REPO_RAW:-https://raw.githubusercontent.com/evertonramires/aiaiai/main}"
DEST="${1:-$HOME/.local/bin}"
NEEDS_NEW_SHELL=""

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$(printf '\033[1m'); D=$(printf '\033[2m'); R=$(printf '\033[31m')
  G=$(printf '\033[32m'); Y=$(printf '\033[33m'); N=$(printf '\033[0m')
else
  B=''; D=''; R=''; G=''; Y=''; N=''
fi

say()  { printf '%s\n' "$*"; }
step() { printf '%s==>%s %s\n' "$B" "$N" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*" >&2; }
fail() { printf '%serror:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

# A terminal to ask questions on, even when this script arrived through a pipe.
if [ -t 0 ]; then
  TTY=/dev/stdin
elif ( : >/dev/tty ) 2>/dev/null; then
  TTY=/dev/tty
else
  TTY=""
fi

ask() { # ask "question" "default"  ->  answer on stdout
  _default="$2"
  [ -z "$TTY" ] && { printf '%s\n' "$_default"; return; }
  printf '%s [%s] ' "$1" "$_default" >&2
  IFS= read -r _answer <"$TTY" || _answer=""
  [ -z "$_answer" ] && _answer="$_default"
  printf '%s\n' "$_answer"
}

confirm() { # confirm "question"  ->  0 if yes
  case "$(ask "$1" "y")" in [yY]*) return 0 ;; *) return 1 ;; esac
}

# --- 1. python ---------------------------------------------------------------
find_python() {
  for candidate in python3 python3.14 python3.13 python3.12 python3.11 python; do
    _path="$(command -v "$candidate" 2>/dev/null)" || continue
    if "$_path" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3,11) else 1)' \
       2>/dev/null; then
      printf '%s\n' "$_path"
      return 0
    fi
  done
  return 1
}

install_python() {
  if [ "$(uname -s)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    step "installing python with homebrew"; brew install python && return 0
  fi
  for mgr in apt-get dnf pacman zypper apk; do
    command -v "$mgr" >/dev/null 2>&1 || continue
    sudo=""
    [ "$(id -u)" -ne 0 ] && { command -v sudo >/dev/null 2>&1 && sudo="sudo"; }
    step "installing python with $mgr (you may be asked for your password)"
    case "$mgr" in
      apt-get) $sudo apt-get update -qq && $sudo apt-get install -y python3 ;;
      dnf)     $sudo dnf install -y python3 ;;
      pacman)  $sudo pacman -Sy --noconfirm python ;;
      zypper)  $sudo zypper install -y python3 ;;
      apk)     $sudo apk add python3 ;;
    esac && return 0
  done
  return 1
}

step "looking for Python 3.11 or newer"
if PYTHON="$(find_python)"; then
  say "  found $PYTHON ($("$PYTHON" -V 2>&1))"
else
  warn "no Python 3.11+ on this machine - aiaiai needs one"
  if [ -n "$TTY" ] && confirm "install Python now? [Y/n]"; then
    install_python || fail "could not install Python automatically. Install it by hand, then re-run this."
    PYTHON="$(find_python)" || fail "Python still not found after installing. Open a new terminal and re-run this."
    say "  found $PYTHON ($("$PYTHON" -V 2>&1))"
  else
    fail "aiaiai needs Python 3.11+. On Debian/Ubuntu: sudo apt install python3"
  fi
fi

# --- 2. the script itself ----------------------------------------------------
# Only trust a local copy when this script really is a file on disk next to it;
# piped through a shell, "$0" is just the shell's name.
HERE=""
if [ -f "$0" ] && [ -f "$(dirname "$0")/aiaiai" ] && [ -f "$(dirname "$0")/install.sh" ]; then
  HERE="$(cd "$(dirname "$0")" && pwd)"
fi
mkdir -p "$DEST"

if [ -n "$HERE" ]; then
  step "installing from $HERE"
  install -m 755 "$HERE/aiaiai" "$DEST/aiaiai"
else
  step "downloading aiaiai"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_RAW/aiaiai" -o "$DEST/aiaiai.tmp" || fail "download failed"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$DEST/aiaiai.tmp" "$REPO_RAW/aiaiai" || fail "download failed"
  else
    fail "need curl or wget to download aiaiai"
  fi
  head -n 1 "$DEST/aiaiai.tmp" | grep -q python || { rm -f "$DEST/aiaiai.tmp"; fail "that download does not look like aiaiai"; }
  mv "$DEST/aiaiai.tmp" "$DEST/aiaiai"
  chmod 755 "$DEST/aiaiai"
fi
say "  installed $DEST/aiaiai"

if [ "${NO_SHORT_ALIAS:-0}" = "1" ]; then
  say "  skipping the short 'ai' alias"
else
  existing="$(command -v ai 2>/dev/null || true)"
  target="$(readlink "$existing" 2>/dev/null || printf '%s' "${existing:-}")"
  if [ -n "$existing" ] && [ "$existing" != "$DEST/ai" ] \
     && [ "$(basename "$target")" != "aiaiai" ]; then
    warn "'ai' is already $existing - leaving it alone"
  else
    ln -sf "$DEST/aiaiai" "$DEST/ai"
    say "  installed $DEST/ai (same program, shorter name)"
  fi
fi

# --- 3. PATH -----------------------------------------------------------------
case ":$PATH:" in
  *":$DEST:"*) ;;
  *)
    rc=""
    case "$(basename "${SHELL:-sh}")" in
      zsh)  rc="$HOME/.zshrc" ;;
      bash) [ "$(uname -s)" = "Darwin" ] && rc="$HOME/.bash_profile" || rc="$HOME/.bashrc" ;;
      fish) rc="$HOME/.config/fish/config.fish" ;;
    esac
    if [ -n "$rc" ] && [ "${NO_PATH_EDIT:-0}" != "1" ]; then
      step "adding $DEST to your PATH in $rc"
      mkdir -p "$(dirname "$rc")"
      if [ "$(basename "$rc")" = "config.fish" ]; then
        printf '\n# added by aiaiai\nfish_add_path %s\n' "$DEST" >>"$rc"
      else
        printf '\n# added by aiaiai\nexport PATH="$PATH:%s"\n' "$DEST" >>"$rc"
      fi
      NEEDS_NEW_SHELL="$rc"
    else
      warn "$DEST is not on your PATH; add it yourself:"
      say  "      export PATH=\"\$PATH:$DEST\""
    fi
    ;;
esac

# --- 4. configuration --------------------------------------------------------
if [ "${NO_SETUP:-0}" = "1" ]; then
  say ""
  say "skipping configuration. Run '$DEST/aiaiai --setup' when you are ready."
elif [ -z "$TTY" ]; then
  say ""
  warn "no terminal available, so configuration was skipped."
  say  "Finish with: $DEST/aiaiai --setup"
else
  say ""
  "$PYTHON" "$DEST/aiaiai" --setup <"$TTY" || true
fi

# --- 5. the one thing left to do --------------------------------------------
say ""
if [ -n "$NEEDS_NEW_SHELL" ]; then
  printf '%sOne last step.%s Copy, paste, and you are done:\n\n' "$B" "$N"
  printf '    %sexec %s%s\n\n' "$G" "${SHELL:-sh}" "$N"
  say "(or just open a new terminal - this is only needed once)"
else
  printf '%sReady.%s Try it:\n\n' "$G" "$N"
  printf '    %sai how do I find the biggest files in this folder%s\n' "$B" "$N"
fi
