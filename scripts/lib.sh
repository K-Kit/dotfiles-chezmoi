# Source from chezmoi onchange scripts after exporting DOT_DIR.
# Single-repo layout: DOT_DIR is the chezmoi working tree (repo root; sibling of home/).

: "${DOT_DIR:?DOT_DIR must be set to the dotfiles checkout (repo root with config/)}"

PROFILE="${CHEZMOI_PROFILE:-${PROFILE:-personal}}"
export PROFILE DOT_DIR
export CHEZMOI_NON_INTERACTIVE="${CHEZMOI_NON_INTERACTIVE:-0}"

if [[ ! -d "$DOT_DIR/config" ]]; then
  echo "  ⚠ DOT_DIR=$DOT_DIR missing config/ — expected single-repo checkout" >&2
  exit 1
fi

# Load zsh config registry + helpers when running under zsh
if [[ -n "${ZSH_VERSION:-}" ]]; then
  # shellcheck disable=SC1091
  source "$DOT_DIR/config.sh"
  # shellcheck disable=SC1091
  source "$DOT_DIR/scripts/shared/helpers.sh"
  if [[ -f "$DOT_DIR/scripts/helpers/dotfiles_secrets.sh" ]]; then
    # shellcheck disable=SC1091
    source "$DOT_DIR/scripts/helpers/dotfiles_secrets.sh"
  fi
  apply_profile "$PROFILE"
fi

chezmoi_deploy_enabled() {
  local name="$1" var
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    var="DEPLOY_${(U)name//-/_}"
    [[ "${(P)var}" == "true" ]]
  else
    var="CHEZMOI_DEPLOY_${name//-/_}"
    var=$(echo "$var" | tr '[:lower:]' '[:upper:]')
    [[ "${!var:-}" == "true" ]]
  fi
}

chezmoi_install_enabled() {
  local name="$1" var
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    var="INSTALL_${(U)name//-/_}"
    [[ "${(P)var}" == "true" ]]
  else
    var="CHEZMOI_INSTALL_${name//-/_}"
    var=$(echo "$var" | tr '[:lower:]' '[:upper:]')
    [[ "${!var:-}" == "true" ]]
  fi
}

log()  { echo "  $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ⚠ $*" >&2; }
