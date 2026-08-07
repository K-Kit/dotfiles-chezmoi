#!/usr/bin/env zsh
# Resolve the chezmoi source path. Single-repo: this checkout is both content and source.
#
# Usage:
#   source "$DOT_DIR/scripts/chezmoi/source.sh"
#   echo "$CHEZMOI_SOURCE"

: "${DOT_DIR:=$(cd "$(dirname "${(%):-%x}")/../.." && pwd)}"

CODE_DIR="${CODE_DIR:-$HOME/code}"
# Prefer this checkout when it contains .chezmoiroot (single-repo layout).
if [[ -f "$DOT_DIR/.chezmoiroot" ]]; then
  CHEZMOI_SOURCE="${CHEZMOI_SOURCE:-$DOT_DIR}"
else
  CHEZMOI_SOURCE="${CHEZMOI_SOURCE:-${CODE_DIR}/dotfiles-chezmoi}"
fi
CHEZMOI_REPO="${CHEZMOI_REPO:-https://github.com/K-Kit/dotfiles-chezmoi.git}"

# Sibling / legacy path fallback
if [[ ! -f "$CHEZMOI_SOURCE/.chezmoiroot" ]]; then
  for _candidate in "$DOT_DIR" "$(cd "$DOT_DIR/.." && pwd)/dotfiles-chezmoi" "$CODE_DIR/dotfiles-chezmoi"; do
    if [[ -f "$_candidate/.chezmoiroot" ]]; then
      CHEZMOI_SOURCE="$_candidate"
      break
    fi
  done
  unset _candidate
fi

export CHEZMOI_SOURCE CHEZMOI_REPO CODE_DIR DOT_DIR

ensure_chezmoi_source() {
  if [[ -f "$CHEZMOI_SOURCE/.chezmoiroot" ]]; then
    return 0
  fi
  if ! command -v git &>/dev/null; then
    echo "Error: git required to clone chezmoi source repo" >&2
    return 1
  fi
  local branch="${CHEZMOI_BRANCH:-main}"
  echo "Cloning chezmoi source → $CHEZMOI_SOURCE"
  mkdir -p "$(dirname "$CHEZMOI_SOURCE")"
  git clone --branch "$branch" "$CHEZMOI_REPO" "$CHEZMOI_SOURCE"
}
