#!/usr/bin/env bash
#
# Trackbed installer.
#
# Trackbed itself is skills-only (no scripts at runtime). This script is
# install-time plumbing only: it copies (or symlinks) the four skills and the
# one command into the right directories for Claude Code and/or OpenCode.
#
# Usage:
#   ./install.sh                 interactive: asks which runtime(s) to install for
#   ./install.sh --link          symlink instead of copy (dev: repo edits go live)
#   ./install.sh --uninstall     remove an existing Trackbed install
#   ./install.sh --help          show this help
#
# Conflict rule (OpenCode reads BOTH ~/.claude/skills and ~/.config/opencode/skills):
# skills get exactly ONE home per machine so the two never drift —
#   * Claude Code only        -> ~/.claude/skills/
#   * OpenCode only           -> ~/.config/opencode/skills/
#   * both runtimes installed -> ~/.claude/skills/ only (OpenCode reads it natively)

set -euo pipefail

# --- paths -------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/claude/skills"
CC_CMD_SRC="$REPO_DIR/claude/commands/trackbed.md"
OC_CMD_SRC="$REPO_DIR/opencode/commands/trackbed.md"

CLAUDE_SKILLS="$HOME/.claude/skills"
CLAUDE_CMDS="$HOME/.claude/commands"
OPENCODE_SKILLS="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills"
OPENCODE_CMDS="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/commands"

SKILLS=(trackbed trackbed-init trackbed-orchestrate trackbed-adr)

LINK=0
MODE="install"

# --- helpers -----------------------------------------------------------------

say()  { printf '%s\n' "$*"; }
err()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^#$//; s/^# //'
  exit 0
}

# place one item (dir or file) from src -> dest, copy or symlink per $LINK
place() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  if [ "$LINK" -eq 1 ]; then
    ln -s "$src" "$dest"
    say "  linked  $dest"
  else
    cp -R "$src" "$dest"
    say "  copied  $dest"
  fi
}

install_skills_to() {
  local target_dir="$1"
  for s in "${SKILLS[@]}"; do
    place "$SKILLS_SRC/$s" "$target_dir/$s"
  done
}

remove_skills_from() {
  local target_dir="$1"
  for s in "${SKILLS[@]}"; do
    if [ -e "$target_dir/$s" ] || [ -L "$target_dir/$s" ]; then
      rm -rf "$target_dir/$s"
      say "  removed $target_dir/$s"
    fi
  done
}

have_skills_in() { [ -e "$1/trackbed/SKILL.md" ] || [ -L "$1/trackbed" ]; }

# --- arg parsing -------------------------------------------------------------

for arg in "$@"; do
  case "$arg" in
    --link)      LINK=1 ;;
    --uninstall) MODE="uninstall" ;;
    --help|-h)   usage ;;
    *)           err "unknown option: $arg (try --help)" ;;
  esac
done

[ -d "$SKILLS_SRC" ] || err "skills not found at $SKILLS_SRC — run this from the trackbed repo"

# --- runtime selection -------------------------------------------------------

WANT_CC=0
WANT_OC=0

say "Trackbed installer"
say "Install for which runtime?"
say "  1) Claude Code"
say "  2) OpenCode"
say "  3) Both"
printf 'Choice [1/2/3]: '
read -r choice
case "$choice" in
  1) WANT_CC=1 ;;
  2) WANT_OC=1 ;;
  3) WANT_CC=1; WANT_OC=1 ;;
  *) err "invalid choice: $choice" ;;
esac

# --- uninstall ---------------------------------------------------------------

if [ "$MODE" = "uninstall" ]; then
  say ""
  say "Uninstalling Trackbed..."
  if [ "$WANT_CC" -eq 1 ]; then
    remove_skills_from "$CLAUDE_SKILLS"
    [ -e "$CLAUDE_CMDS/trackbed.md" ] && { rm -f "$CLAUDE_CMDS/trackbed.md"; say "  removed $CLAUDE_CMDS/trackbed.md"; }
  fi
  if [ "$WANT_OC" -eq 1 ]; then
    remove_skills_from "$OPENCODE_SKILLS"
    [ -e "$OPENCODE_CMDS/trackbed.md" ] && { rm -f "$OPENCODE_CMDS/trackbed.md"; say "  removed $OPENCODE_CMDS/trackbed.md"; }
  fi
  say "Done."
  exit 0
fi

# --- install: decide the single skill home -----------------------------------

say ""

if [ "$WANT_CC" -eq 1 ] && [ "$WANT_OC" -eq 1 ]; then
  # Both runtimes -> skills live in ~/.claude/skills only; OpenCode reads it natively.
  say "Both runtimes selected — skills go to ~/.claude/skills (OpenCode reads it natively)."
  install_skills_to "$CLAUDE_SKILLS"
  # If a stale OpenCode-native copy exists, remove it so the two can't drift.
  if have_skills_in "$OPENCODE_SKILLS"; then
    say "Removing duplicate skills under OpenCode to avoid drift:"
    remove_skills_from "$OPENCODE_SKILLS"
  fi
  place "$CC_CMD_SRC" "$CLAUDE_CMDS/trackbed.md"
  place "$OC_CMD_SRC" "$OPENCODE_CMDS/trackbed.md"

elif [ "$WANT_CC" -eq 1 ]; then
  install_skills_to "$CLAUDE_SKILLS"
  place "$CC_CMD_SRC" "$CLAUDE_CMDS/trackbed.md"

else
  # OpenCode only. If a Claude install already exists, reuse it (OpenCode reads it).
  if have_skills_in "$CLAUDE_SKILLS"; then
    say "Found existing skills in ~/.claude/skills — OpenCode reads that path natively,"
    say "so skills are left there (not duplicated under OpenCode)."
  else
    install_skills_to "$OPENCODE_SKILLS"
  fi
  place "$OC_CMD_SRC" "$OPENCODE_CMDS/trackbed.md"
fi

say ""
say "Done. Invoke with /trackbed <jira-epic-key | project-slug>"
