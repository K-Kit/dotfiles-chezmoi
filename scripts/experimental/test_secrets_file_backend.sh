#!/usr/bin/env bash
# Hermetic test for file (age) and fnox secrets backends — no Bitwarden.
set -euo pipefail

REAL_DOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER="$REAL_DOT/custom_bins/dotfiles-secrets"

# Prefer concrete tool bins over mise shims (shims break when HOME is remapped).
FNOX_BIN="$(command -v fnox 2>/dev/null || true)"
if [[ -z "$FNOX_BIN" || "$FNOX_BIN" == *"/mise/shims/"* ]]; then
  FNOX_BIN="$(find "${HOME}/.local/share/mise/installs" -name fnox -type f 2>/dev/null | head -1 || true)"
fi
AGE_BIN_DIR="$(dirname "$(command -v age)")"
PATH_PREFIX="$AGE_BIN_DIR"
[[ -n "$FNOX_BIN" ]] && PATH_PREFIX="$(dirname "$FNOX_BIN"):$PATH_PREFIX"
export PATH="${PATH_PREFIX}:/usr/bin:/bin:${PATH}"

command -v age >/dev/null || { echo "SKIP: age not installed"; exit 0; }
command -v age-keygen >/dev/null || { echo "SKIP: age-keygen not installed"; exit 0; }

TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT
export HOME="$TEST_HOME"
unset BWS_ACCESS_TOKEN DOTFILES_SECRETS_BACKEND FNOX_AGE_KEY_FILE AGE_IDENTITY_FILE FNOX_CONFIG_PATH
# Keep helper able to source repo scripts
export DOT_DIR="$REAL_DOT"
mkdir -p "$TEST_HOME/.cache/dotfiles-secrets"

pass=0; fail=0
check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ok  $name"
    pass=$((pass+1))
  else
    echo "  FAIL $name"
    echo "    expected: ${expected@Q}"
    echo "    actual:   ${actual@Q}"
    fail=$((fail+1))
  fi
}

run_helper() {
  env HOME="$TEST_HOME" DOT_DIR="$REAL_DOT" PATH="$PATH" \
      BWS_ACCESS_TOKEN= DOTFILES_SECRETS_BACKEND="${DOTFILES_SECRETS_BACKEND:-}" \
      FNOX_CONFIG_PATH="${FNOX_CONFIG_PATH:-}" \
      FNOX_AGE_KEY_FILE="${FNOX_AGE_KEY_FILE:-}" \
      AGE_IDENTITY_FILE="${AGE_IDENTITY_FILE:-}" \
      "$HELPER" "$@"
}

echo "== auto-detect with nothing configured =="
# shellcheck source=/dev/null
source "$REAL_DOT/scripts/helpers/dotfiles_secrets.sh"
check "backend none" "none" "$(dotfiles_secrets_backend)"

echo "== file backend =="
secrets_dir="$TEST_HOME/.config/dotfiles-secrets"
mkdir -p "$secrets_dir"
chmod 700 "$secrets_dir"
key_file="$secrets_dir/age.key"
enc_file="$secrets_dir/secrets.env.enc"
age-keygen -o "$key_file" >/dev/null
chmod 600 "$key_file"
printf 'OPENAI_API_KEY=sk-test-123\nHF_TOKEN=hf_abc\n' | age -e -i "$key_file" -o "$enc_file"
chmod 600 "$enc_file"

check "backend file" "file" "$(dotfiles_secrets_backend)"

keys=$(run_helper keys | tr '\n' ' ' | sed 's/ *$//')
check "keys list" "HF_TOKEN OPENAI_API_KEY" "$keys"

val=$(run_helper get-value OPENAI_API_KEY)
check "get-value" "sk-test-123" "$val"

run_helper set ANTHROPIC_API_KEY "sk-ant-xyz" >/dev/null
val=$(run_helper get-value ANTHROPIC_API_KEY)
check "set+get" "sk-ant-xyz" "$val"

shell_out=$(run_helper shell OPENAI_API_KEY)
case "$shell_out" in
  export\ OPENAI_API_KEY=*) check "shell export" "ok" "ok" ;;
  *) check "shell export" "export OPENAI_API_KEY=..." "$shell_out" ;;
esac

run_helper rm --yes HF_TOKEN >/dev/null
if run_helper get-value HF_TOKEN >/dev/null 2>&1; then
  check "rm removes key" "missing" "still present"
else
  check "rm removes key" "missing" "missing"
fi

echo "== fnox backend =="
if ! command -v fnox >/dev/null; then
  echo "  SKIP fnox: not installed"
else
  rm -f "$enc_file"
  fnox_dir="$TEST_HOME/proj"
  mkdir -p "$fnox_dir" "$TEST_HOME/.config/fnox"
  cp "$key_file" "$TEST_HOME/.config/fnox/age.txt"
  chmod 600 "$TEST_HOME/.config/fnox/age.txt"
  pubkey=$(grep '# public key:' "$TEST_HOME/.config/fnox/age.txt" | awk '{print $4}')
  cat > "$fnox_dir/fnox.toml" <<EOF
default_provider = "encrypted"

[providers.encrypted]
type = "age"
recipients = ["$pubkey"]
key_file = "$TEST_HOME/.config/fnox/age.txt"

[secrets]
EOF

  export DOTFILES_SECRETS_BACKEND=fnox
  export FNOX_CONFIG_PATH="$fnox_dir/fnox.toml"
  export FNOX_AGE_KEY_FILE="$TEST_HOME/.config/fnox/age.txt"

  run_helper set DEMO_SECRET "fnox-value-1" >/dev/null
  got=$(run_helper get-value DEMO_SECRET)
  check "fnox get-value" "fnox-value-1" "$got"

  backend=$(run_helper paths | sed -n 's/^DOTFILES_SECRETS_BACKEND=//p')
  check "fnox backend path" "fnox" "$backend"

  # Auto-detect fnox when file store absent and DOT_DIR has fnox.toml
  unset DOTFILES_SECRETS_BACKEND
  export DOT_DIR="$fnox_dir"
  # Re-source with test DOT_DIR — helper still needs REAL_DOT scripts, so only test the helper function
  # shellcheck source=/dev/null
  source "$REAL_DOT/scripts/helpers/dotfiles_secrets.sh"
  check "auto-detect fnox" "fnox" "$(dotfiles_secrets_backend)"
  export DOT_DIR="$REAL_DOT"
fi

echo
echo "PASS=$pass FAIL=$fail"
exit "$fail"
