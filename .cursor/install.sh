#!/usr/bin/env bash
# Cloud Agent install phase for the dotfiles-chezmoi repo.
#
# Installs the toolchain needed to develop and validate this repo:
#   - zsh / shellcheck / tmux : the scripts are zsh; AGENTS.md lints with shellcheck
#   - chezmoi                 : the primary apply/deploy engine (the "app")
#   - uv                      : runs the Python test suite (tests/*.py)
#   - Rust stable >= 1.85     : tools/claude-tools needs edition-2024 crates
#
# It then generates the chezmoi config for this checkout (cloud profile) so a
# fresh agent can immediately run `chezmoi managed` / `chezmoi apply`.
#
# Idempotent and non-interactive: safe to re-run against a warm machine.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

log() { echo "  → $*"; }

# ── System packages (zsh scripts + shellcheck lint + tmux config) ──────────────
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  need=()
  for pkg in zsh shellcheck tmux; do
    dpkg -s "$pkg" >/dev/null 2>&1 || need+=("$pkg")
  done
  if [[ ${#need[@]} -gt 0 ]]; then
    log "apt-get install ${need[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y -qq "${need[@]}" </dev/null
  else
    log "system packages already present (zsh shellcheck tmux)"
  fi
fi

# ── chezmoi (primary deploy engine) ────────────────────────────────────────────
if ! command -v chezmoi >/dev/null 2>&1; then
  log "installing chezmoi → /usr/local/bin"
  sudo sh -c "$(curl -fsSL get.chezmoi.io)" -- -b /usr/local/bin
else
  log "chezmoi already present ($(chezmoi --version | head -1))"
fi

# ── uv (Python test runner) ─────────────────────────────────────────────────────
if ! command -v uv >/dev/null 2>&1; then
  log "installing uv → /usr/local/bin"
  curl -LsSf https://astral.sh/uv/install.sh \
    | sudo env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh
else
  log "uv already present ($(uv --version))"
fi

# ── Rust stable (claude-tools needs edition 2024 / rustc >= 1.85) ───────────────
if command -v rustup >/dev/null 2>&1; then
  current="$(rustc --version 2>/dev/null | awk '{print $2}')"
  # Update when the active rustc predates 1.85 (first edition-2024 stable).
  if printf '%s\n1.85.0\n' "$current" | sort -V | head -1 | grep -qxF "$current" \
     && [[ "$current" != "1.85.0" ]]; then
    log "updating Rust stable (have $current, need >= 1.85 for edition 2024)"
    rustup update stable
    rustup default stable
  else
    log "Rust stable is current enough ($current)"
  fi
else
  log "rustup not found — skipping Rust update (claude-tools build unavailable)"
fi

# ── Generate chezmoi config for this checkout (cloud profile) ───────────────────
# Produces ~/.config/chezmoi/chezmoi.toml pointing dot_dir at this working tree,
# so `chezmoi managed` / `chezmoi apply` work out of the box.
export CHEZMOI_PROFILE="${CHEZMOI_PROFILE:-cloud}"
export CHEZMOI_NON_INTERACTIVE=1
log "chezmoi init (profile=$CHEZMOI_PROFILE, source=$REPO_DIR)"
chezmoi --source "$REPO_DIR" init --force
managed_count="$(chezmoi --source "$REPO_DIR" managed | wc -l | tr -d ' ')"
log "chezmoi manages $managed_count entries for this checkout"

echo "  ✓ dotfiles-chezmoi dev environment ready"
