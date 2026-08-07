#!/bin/bash
# shellcheck shell=bash
# Shared path helpers for the private dotfiles secrets store.
# Safe to source from bash or zsh.
#
# Backends (auto-detect order when DOTFILES_SECRETS_BACKEND is unset):
#   1. bws  — Bitwarden Secrets Manager (token + bws CLI)
#   2. file — age-encrypted dotenv at $DOTFILES_SECRETS_DIR/secrets.env.enc
#   3. fnox — project fnox.toml (age / other providers) via fnox CLI
#   4. none

dotfiles_secrets_dir() {
    printf '%s\n' "${DOTFILES_SECRETS_DIR:-$HOME/.config/dotfiles-secrets}"
}

dotfiles_secrets_bws_token_file() {
    printf '%s\n' "${BWS_TOKEN_FILE:-$HOME/.config/bws/token}"
}

dotfiles_secrets_enc_file() {
    printf '%s\n' "$(dotfiles_secrets_dir)/secrets.env.enc"
}

dotfiles_secrets_age_key_file() {
    # Prefer an explicit override, then the private store key, then common age locations.
    if [[ -n "${AGE_IDENTITY_FILE:-}" ]]; then
        printf '%s\n' "$AGE_IDENTITY_FILE"
        return
    fi
    local candidates=(
        "$(dotfiles_secrets_dir)/age.key"
        "${HOME}/.config/fnox/age.txt"
        "${HOME}/.config/sops/age/keys.txt"
    )
    local f
    for f in "${candidates[@]}"; do
        if [[ -f "$f" ]]; then
            printf '%s\n' "$f"
            return
        fi
    done
    # Default create path for secrets-init file
    printf '%s\n' "$(dotfiles_secrets_dir)/age.key"
}

dotfiles_secrets_fnox_config() {
    if [[ -n "${FNOX_CONFIG_PATH:-}" ]]; then
        printf '%s\n' "$FNOX_CONFIG_PATH"
        return
    fi
    local root="${DOT_DIR:-}"
    if [[ -n "$root" && -f "$root/fnox.toml" ]]; then
        printf '%s\n' "$root/fnox.toml"
        return
    fi
    if [[ -f "./fnox.toml" ]]; then
        printf '%s\n' "$(pwd)/fnox.toml"
        return
    fi
    printf '%s\n' "${root:+$root/}fnox.toml"
}

dotfiles_secrets_age_available() {
    command -v age >/dev/null 2>&1 || return 1
    local key
    key=$(dotfiles_secrets_age_key_file)
    [[ -f "$key" ]]
}

dotfiles_secrets_backend() {
    local explicit="${DOTFILES_SECRETS_BACKEND:-}"
    if [[ -n "$explicit" ]]; then
        printf '%s\n' "$explicit"
        return
    fi

    # 1) Bitwarden Secrets Manager
    if { [[ -n "${BWS_ACCESS_TOKEN:-}" ]] || [[ -f "$(dotfiles_secrets_bws_token_file)" ]]; } && \
       command -v bws >/dev/null 2>&1; then
        printf 'bws\n'
        return
    fi

    # 2) Local age-encrypted dotenv (documented secrets.env.enc path)
    if [[ -f "$(dotfiles_secrets_enc_file)" ]] && dotfiles_secrets_age_available; then
        printf 'file\n'
        return
    fi

    # 3) fnox.toml + fnox CLI (works offline with age provider; no Bitwarden required)
    local fnox_cfg
    fnox_cfg=$(dotfiles_secrets_fnox_config)
    if [[ -f "$fnox_cfg" ]] && command -v fnox >/dev/null 2>&1 && dotfiles_secrets_age_available; then
        printf 'fnox\n'
        return
    fi

    printf 'none\n'
}

dotfiles_secrets_harden_permissions() {
    local secrets_dir enc_file age_key bws_token fnox_age

    secrets_dir=$(dotfiles_secrets_dir)
    if [[ -d "$secrets_dir" ]]; then chmod 700 "$secrets_dir" 2>/dev/null || true; fi

    enc_file=$(dotfiles_secrets_enc_file)
    if [[ -f "$enc_file" ]]; then chmod 600 "$enc_file" 2>/dev/null || true; fi

    age_key=$(dotfiles_secrets_age_key_file)
    if [[ -f "$age_key" ]]; then chmod 600 "$age_key" 2>/dev/null || true; fi
    if [[ -d "$(dirname "$age_key")" ]]; then chmod 700 "$(dirname "$age_key")" 2>/dev/null || true; fi

    bws_token=$(dotfiles_secrets_bws_token_file)
    if [[ -f "$bws_token" ]]; then chmod 600 "$bws_token" 2>/dev/null || true; fi
    if [[ -d "$(dirname "$bws_token")" ]]; then chmod 700 "$(dirname "$bws_token")" 2>/dev/null || true; fi

    fnox_age="${HOME}/.config/fnox/age.txt"
    if [[ -f "$fnox_age" ]]; then chmod 600 "$fnox_age" 2>/dev/null || true; fi
    if [[ -d "${HOME}/.config/fnox" ]]; then chmod 700 "${HOME}/.config/fnox" 2>/dev/null || true; fi
}

telegram_state_harden_permissions() {
    local state_dir="$1"

    [[ -n "$state_dir" ]] || return 0
    if [[ -d "$state_dir" ]]; then chmod 700 "$state_dir" 2>/dev/null || true; fi
    if [[ -f "$state_dir/.env" ]]; then chmod 600 "$state_dir/.env" 2>/dev/null || true; fi
    if [[ -f "$state_dir/access.json" ]]; then chmod 600 "$state_dir/access.json" 2>/dev/null || true; fi

    if [[ -d "$state_dir/approved" ]]; then
        chmod 700 "$state_dir/approved" 2>/dev/null || true
        find "$state_dir/approved" -type f -exec chmod 600 {} + 2>/dev/null || true
    fi
}

project_secret_harden_permissions() {
    local project_root="${1:-.}"
    local envrc="$project_root/.envrc"
    local env_file

    if [[ -f "$envrc" ]]; then chmod 600 "$envrc" 2>/dev/null || true; fi

    while IFS= read -r env_file; do
        [[ -n "$env_file" ]] || continue
        chmod 600 "$env_file" 2>/dev/null || true
    done < <(
        find "$project_root" \
            \( \
                -path "$project_root/.git" -o \
                -path "$project_root/.direnv" -o \
                -path "$project_root/node_modules" -o \
                -path "$project_root/.venv" -o \
                -path "$project_root/venv" -o \
                -path "$project_root/build" -o \
                -path "$project_root/dist" -o \
                -path "$project_root/claude/plugins/cache" -o \
                -path "$project_root/claude/plugins/plugins.bak" -o \
                -path "$project_root/codex/.tmp" \
            \) -prune -o \
            -type f -name '.env' -print
    )

    if [[ -d "$project_root/.claude/channels/telegram" ]]; then
        telegram_state_harden_permissions "$project_root/.claude/channels/telegram"
    fi
}
