#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)
CURSOR_REMOTE="$ROOT_DIR/custom_bins/cursor-remote"
WARP_REMOTE="$ROOT_DIR/custom_bins/warp-remote"
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/remote-openers.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT HUP INT TERM

MOCK_BIN="$TEST_TMP/bin"
CURSOR_BIN="$TEST_TMP/cursor-bin"
REMOTE_BIN="$TEST_TMP/remote-bin"
TEST_HOME="$TEST_TMP/home"
SSH_LOG="$TEST_TMP/ssh.log"
CURSOR_LOG="$TEST_TMP/cursor.log"
OPEN_LOG="$TEST_TMP/open.log"
REMOTE_LOG="$TEST_TMP/remote.log"
STREAM_FILE="$TEST_TMP/streamed-launcher"
SYSTEM_PATH=$PATH

mkdir -p "$MOCK_BIN" "$CURSOR_BIN" "$REMOTE_BIN" "$TEST_HOME"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file_equals() {
  expected=$1
  actual=$2
  description=$3
  if ! diff -u "$expected" "$actual"; then
    fail "$description"
  fi
}

assert_mode_600() {
  file=$1
  mode=$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file")
  [ "$mode" = 600 ] || fail "$file mode was $mode, expected 600"
}

reset_logs() {
  : > "$SSH_LOG"
  : > "$CURSOR_LOG"
  : > "$OPEN_LOG"
  : > "$REMOTE_LOG"
  : > "$STREAM_FILE"
}

cat > "$MOCK_BIN/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${MOCK_UNAME:-Darwin}"
EOF

cat > "$CURSOR_BIN/cursor" <<'EOF'
#!/bin/sh
set -eu
for arg do
  printf '<%s>\n' "$arg"
done >> "$CURSOR_LOG"
EOF

cat > "$MOCK_BIN/open" <<'EOF'
#!/bin/sh
set -eu
for arg do
  printf '<%s>\n' "$arg"
done >> "$OPEN_LOG"
EOF

cat > "$REMOTE_BIN/cursor-remote" <<'EOF'
#!/bin/sh
set -eu
printf '<cursor-remote>\n' >> "$REMOTE_LOG"
for arg do
  printf '<%s>\n' "$arg"
done >> "$REMOTE_LOG"
EOF

cat > "$REMOTE_BIN/warp-remote" <<'EOF'
#!/bin/sh
set -eu
printf '<warp-remote>\n' >> "$REMOTE_LOG"
for arg do
  printf '<%s>\n' "$arg"
done >> "$REMOTE_LOG"
EOF

cat > "$MOCK_BIN/ssh" <<'EOF'
#!/bin/sh
set -eu

[ "${1:-}" = -- ] && shift
host=${1:?missing SSH host}
shift
remote_command=${1:?missing remote command}
shift
[ "$#" -eq 0 ] || exit 91

printf '<host=%s>\n<command=%s>\n' "$host" "$remote_command" >> "$SSH_LOG"

case "$remote_command" in
  'command -v cursor-remote >/dev/null 2>&1')
    [ "${MOCK_CURSOR_REMOTE_INSTALLED:-0}" = 1 ]
    exit
    ;;
  'command -v warp-remote >/dev/null 2>&1')
    [ "${MOCK_WARP_REMOTE_INSTALLED:-0}" = 1 ]
    exit
    ;;
  'sh -s -- '*)
    cat > "$STREAM_FILE"
    MOCK_UNAME=Darwin PATH="$MOCK_BIN:$CURSOR_BIN:$SYSTEM_PATH" \
      /bin/sh -c "$remote_command" < "$STREAM_FILE"
    ;;
  *)
    MOCK_UNAME=Darwin PATH="$REMOTE_BIN:$MOCK_BIN:$CURSOR_BIN:$SYSTEM_PATH" \
      /bin/sh -c "$remote_command"
    ;;
esac
EOF

chmod +x "$MOCK_BIN/uname" "$MOCK_BIN/open" "$MOCK_BIN/ssh" \
  "$CURSOR_BIN/cursor" "$REMOTE_BIN/cursor-remote" "$REMOTE_BIN/warp-remote"

export MOCK_BIN CURSOR_BIN REMOTE_BIN TEST_HOME SSH_LOG CURSOR_LOG OPEN_LOG
export REMOTE_LOG STREAM_FILE SYSTEM_PATH
export HOME="$TEST_HOME"

[ -x "$CURSOR_REMOTE" ] || fail "$CURSOR_REMOTE is missing or not executable"
[ -x "$WARP_REMOTE" ] || fail "$WARP_REMOTE is missing or not executable"

# A wrong Cursor argument, remote URI, or path makes this test fail.
reset_logs
PATH="$MOCK_BIN:$CURSOR_BIN:$SYSTEM_PATH" MOCK_UNAME=Darwin \
  "$CURSOR_REMOTE" --host "gpu'box" -- "/srv/work dir/O'Reilly"
cat > "$TEST_TMP/expected-cursor.log" <<'EOF'
<--remote>
<ssh-remote+gpu'box>
</srv/work dir/O'Reilly>
EOF
assert_file_equals "$TEST_TMP/expected-cursor.log" "$CURSOR_LOG" \
  'Cursor did not receive the exact Remote SSH arguments'

# Removing PATH discovery must select the system-wide bundled CLI first.
reset_logs
SYSTEM_CURSOR="$TEST_TMP/system/Cursor.app/Contents/Resources/app/bin/cursor"
USER_CURSOR="$TEST_HOME/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
mkdir -p "$(dirname "$SYSTEM_CURSOR")" "$(dirname "$USER_CURSOR")"
cp "$CURSOR_BIN/cursor" "$SYSTEM_CURSOR"
cp "$CURSOR_BIN/cursor" "$USER_CURSOR"
chmod +x "$SYSTEM_CURSOR" "$USER_CURSOR"
PATH="$MOCK_BIN:$SYSTEM_PATH" MOCK_UNAME=Darwin \
  DOTFILES_CURSOR_SYSTEM_CLI="$SYSTEM_CURSOR" \
  "$CURSOR_REMOTE" --host pop-os /home/kit
cat > "$TEST_TMP/expected-cursor.log" <<'EOF'
<--remote>
<ssh-remote+pop-os>
</home/kit>
EOF
assert_file_equals "$TEST_TMP/expected-cursor.log" "$CURSOR_LOG" \
  'Cursor did not use the system-wide bundled CLI fallback'

# Removing the system bundle must select ~/Applications/Cursor.app.
reset_logs
PATH="$MOCK_BIN:$SYSTEM_PATH" MOCK_UNAME=Darwin \
  DOTFILES_CURSOR_SYSTEM_CLI="$TEST_TMP/missing-system-cursor" \
  "$CURSOR_REMOTE" --host pop-os /home/kit
assert_file_equals "$TEST_TMP/expected-cursor.log" "$CURSOR_LOG" \
  'Cursor did not use the per-user bundled CLI fallback'

ORIGIN="$TEST_TMP/origin dir/O'Reilly/project"
mkdir -p "$ORIGIN/-child"
ORIGIN_REAL=$(CDPATH='' cd -- "$ORIGIN" && pwd -P)
PARENT_REAL=$(CDPATH='' cd -- "$ORIGIN/.." && pwd -P)

# A missing origin-side normalization or unsafe installed-command quoting fails here.
reset_logs
(
  cd "$ORIGIN"
  PATH="$MOCK_BIN:$CURSOR_BIN:$SYSTEM_PATH" MOCK_UNAME=Linux \
    MOCK_CURSOR_REMOTE_INSTALLED=1 DOTFILES_LAUNCHER_HOST=mac-workstation \
    "$CURSOR_REMOTE" --host "gpu'box" .
)
cat > "$TEST_TMP/expected-remote.log" <<EOF
<cursor-remote>
<--host>
<gpu'box>
<-->
<$ORIGIN_REAL>
EOF
assert_file_equals "$TEST_TMP/expected-remote.log" "$REMOTE_LOG" \
  'installed cursor-remote did not receive normalized, safely quoted arguments'
grep -F '<host=mac-workstation>' "$SSH_LOG" >/dev/null || \
  fail 'cursor-remote ignored DOTFILES_LAUNCHER_HOST'

# A missing fallback or a different streamed file fails byte-for-byte.
reset_logs
(
  cd "$ORIGIN"
  PATH="$MOCK_BIN:$CURSOR_BIN:$SYSTEM_PATH" MOCK_UNAME=Linux \
    MOCK_CURSOR_REMOTE_INSTALLED=0 DOTFILES_LAUNCHER_HOST=mac-workstation \
    "$CURSOR_REMOTE" --host pop-os ..
)
cmp "$CURSOR_REMOTE" "$STREAM_FILE" || fail 'cursor-remote did not stream its exact source'
cat > "$TEST_TMP/expected-cursor.log" <<EOF
<--remote>
<ssh-remote+pop-os>
<$PARENT_REAL>
EOF
assert_file_equals "$TEST_TMP/expected-cursor.log" "$CURSOR_LOG" \
  'streamed cursor-remote did not open the normalized parent directory'

# A wrong Warp host/path command, public mode, or launch URI fails here.
reset_logs
rm -rf "$TEST_HOME/.warp"
PATH="$MOCK_BIN:$CURSOR_BIN:$SYSTEM_PATH" MOCK_UNAME=Darwin \
  "$WARP_REMOTE" --host pop-os -- "/srv/work dir/O'Reilly"
WARP_CONFIG="$TEST_HOME/.warp/launch_configurations/dotfiles-remote.yaml"
[ -f "$WARP_CONFIG" ] || fail 'warp-remote did not create its launch configuration'
assert_mode_600 "$WARP_CONFIG"
cat > "$TEST_TMP/expected-warp-config" <<'EOF'
---
name: dotfiles-remote
windows:
  - tabs:
      - title: dotfiles-remote
        layout:
          commands:
            - exec: >-
                ssh -t 'pop-os' "cd -- '/srv/work dir/O'\''Reilly' && exec \${SHELL:-/bin/zsh} -l"
EOF
assert_file_equals "$TEST_TMP/expected-warp-config" "$WARP_CONFIG" \
  'Warp configuration did not use the documented commands schema'
cat > "$TEST_TMP/expected-open.log" <<'EOF'
<warp://launch/dotfiles-remote>
EOF
assert_file_equals "$TEST_TMP/expected-open.log" "$OPEN_LOG" \
  'warp-remote opened the wrong launch URI'

# Warp must use an installed launcher and normalize .. before relaying.
reset_logs
(
  cd "$ORIGIN"
  PATH="$MOCK_BIN:$CURSOR_BIN:$SYSTEM_PATH" MOCK_UNAME=Linux \
    MOCK_WARP_REMOTE_INSTALLED=1 DOTFILES_LAUNCHER_HOST=mac-workstation \
    "$WARP_REMOTE" --host pop-os ..
)
cat > "$TEST_TMP/expected-remote.log" <<EOF
<warp-remote>
<--host>
<pop-os>
<-->
<$PARENT_REAL>
EOF
assert_file_equals "$TEST_TMP/expected-remote.log" "$REMOTE_LOG" \
  'installed warp-remote did not receive the normalized parent directory'

# Warp must also stream itself when absent on the launcher host.
reset_logs
rm -rf "$TEST_HOME/.warp"
WARP_ORIGIN="$TEST_TMP/warp origin/project"
mkdir -p "$WARP_ORIGIN"
WARP_ORIGIN_REAL=$(CDPATH='' cd -- "$WARP_ORIGIN" && pwd -P)
(
  cd "$WARP_ORIGIN"
  PATH="$MOCK_BIN:$CURSOR_BIN:$SYSTEM_PATH" MOCK_UNAME=Linux \
    MOCK_WARP_REMOTE_INSTALLED=0 DOTFILES_LAUNCHER_HOST=mac-workstation \
    "$WARP_REMOTE" --host pop-os .
)
cmp "$WARP_REMOTE" "$STREAM_FILE" || fail 'warp-remote did not stream its exact source'
grep -F "$WARP_ORIGIN_REAL" "$WARP_CONFIG" >/dev/null || \
  fail 'streamed warp-remote did not preserve the normalized directory'

# -- is required for a path beginning with -, and that path still normalizes.
reset_logs
(
  cd "$ORIGIN"
  PATH="$MOCK_BIN:$CURSOR_BIN:$SYSTEM_PATH" MOCK_UNAME=Linux \
    MOCK_CURSOR_REMOTE_INSTALLED=1 DOTFILES_LAUNCHER_HOST=mac-workstation \
    "$CURSOR_REMOTE" --host pop-os -- -child
)
CHILD_REAL=$(CDPATH='' cd -- "$ORIGIN/-child" && pwd -P)
grep -F "<$CHILD_REAL>" "$REMOTE_LOG" >/dev/null || \
  fail 'path beginning with - was not accepted after --'

assert_rejected() {
  opener=$1
  shift
  if PATH="$MOCK_BIN:$CURSOR_BIN:$SYSTEM_PATH" MOCK_UNAME=Darwin \
    "$opener" "$@" >/dev/null 2>&1; then
    fail "$(basename "$opener") accepted invalid arguments: $*"
  fi
}

newline_host=$(printf 'pop\nos')
newline_path=$(printf '/home/kit\nother')
for opener in "$CURSOR_REMOTE" "$WARP_REMOTE"; do
  assert_rejected "$opener" --unknown
  assert_rejected "$opener" --host
  assert_rejected "$opener" --host '' /home/kit
  assert_rejected "$opener" --host pop-os ''
  assert_rejected "$opener" one two
  assert_rejected "$opener" --host "$newline_host" /home/kit
  assert_rejected "$opener" --host pop-os "$newline_path"
done

printf 'remote opener tests passed\n'
