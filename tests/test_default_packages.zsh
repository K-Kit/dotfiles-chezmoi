#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${0:A:h:h}"
DOT_DIR="$REPO_ROOT"
export DOT_DIR

source "$REPO_ROOT/config.sh"

array_contains() {
    local needle="$1"
    shift

    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

array_contains "watch" "${PACKAGES_MACOS[@]}" || {
    print -u2 "Expected PACKAGES_MACOS to include Homebrew formula: watch"
    exit 1
}

for package in age sops yq watchexec lazydocker shfmt; do
    array_contains "$package" "${PACKAGES_MACOS[@]}" || {
        print -u2 "Expected PACKAGES_MACOS to include Homebrew formula: $package"
        exit 1
    }
done

for package in \
    github:FiloSottile/age \
    github:getsops/sops \
    github:mikefarah/yq \
    github:watchexec/watchexec \
    github:jesseduffield/lazydocker \
    github:mvdan/sh; do
    array_contains "$package" "${PACKAGES_LINUX_MISE[@]}" || {
        print -u2 "Expected PACKAGES_LINUX_MISE to include: $package"
        exit 1
    }
done

for component in "${INSTALL_REGISTRY[@]}"; do
    [[ "$component" == secrets-cli\|* ]] && exit 0
done

print -u2 "Expected INSTALL_REGISTRY to include secrets-cli"
exit 1
