# Cloud Setup

Setup scripts for RunPod containers, plus cloud-init for generic VMs.

Dotfiles are applied with **[chezmoi](https://www.chezmoi.io/)** from this repo (`CHEZMOI_PROFILE=cloud`). One clone under `~/code/dotfiles-chezmoi` is both chezmoi source and content. OS infra stays in shell scripts outside chezmoi.

## Cloud-init (VMs)

[`cloud-init.yaml`](./cloud-init.yaml) is `#cloud-config` user-data that mirrors
`create-user.sh` + `setup.sh` for Hetzner / DigitalOcean / AWS / Multipass / etc.
(no RunPod `/workspace` symlinks).

```bash
# Multipass
multipass launch --name box --cloud-init scripts/cloud/cloud-init.yaml

# Or paste scripts/cloud/cloud-init.yaml into the provider's user-data field
```

Defaults in this fork: user `kit`, GitHub `K-Kit`, repo `K-Kit/dotfiles-chezmoi`.
Override via the `write_files` → `/etc/dotfiles-bootstrap.env` block (username,
repo, branch, optional `BWS_TOKEN` / `TAILSCALE_AUTH_KEY`).

First boot runs `/usr/local/sbin/dotfiles-cloud-bootstrap` once (marker:
`/var/lib/dotfiles-cloud-bootstrap.done`). Logs: `/var/log/cloud-init-output.log`.

`setup.sh` installs chezmoi, clones this repo once, and runs:

```bash
CHEZMOI_PROFILE=cloud CHEZMOI_NON_INTERACTIVE=1 DOT_DIR=~/code/dotfiles-chezmoi \
  chezmoi --source ~/code/dotfiles-chezmoi apply
```

## Two-Script Flow (RunPod)

```
create-user.sh   ← infra: non-root user + SSH + /workspace symlinks (idempotent)
setup.sh         ← tools: zsh/vim/tmux (hard) + chezmoi apply / gh / uv / tailscale (soft)
```

**First boot (run as root):**
```bash
# 1. Create user (infra only — fast, idempotent)
curl -fsSL https://raw.githubusercontent.com/K-Kit/dotfiles-chezmoi/main/scripts/cloud/create-user.sh | bash

# 2. Install tools + chezmoi apply (branch required)
curl -fsSL https://raw.githubusercontent.com/K-Kit/dotfiles-chezmoi/main/scripts/cloud/setup.sh | bash -s -- main

# 3. Switch to user
su - kit
```

**After pod restart (recreates user + symlinks lost from ephemeral /home):**
```bash
curl -fsSL https://raw.githubusercontent.com/K-Kit/dotfiles-chezmoi/main/scripts/cloud/restart.sh | bash
su - kit
```

**If you have permission issues** (ran things as root):
```bash
curl -fsSL https://raw.githubusercontent.com/K-Kit/dotfiles-chezmoi/main/scripts/cloud/fix_permissions.sh | bash
su - kit
```

## What Each Script Does

### create-user.sh

Idempotent — safe to re-run (also runs on `restart.sh`).

- `apt install sudo zsh openssh-server`
- Creates non-root user with zsh as login shell, NOPASSWD sudo
- Symlinks `/workspace/{code,.claude,.local,.config}` into `~/` (RunPod persistence)
- Configures sshd (PubkeyAuthentication, StrictModes on volume-mounted FSes)
- Installs SSH authorized_keys from GitHub + root's keys
- Generates outbound `~/.ssh/id_ed25519` for git/gh

### setup.sh

Tiered installs — **zsh/vim/tmux** fail loud; everything else warns and continues.

| Tier | Tools |
|------|-------|
| **Hard** (abort on fail) | zsh, vim, tmux |
| **Soft** (warn + continue) | mosh, rsync, locale, uv, **chezmoi + apply (profile=cloud)**, gh, claude, tailscale, BWS token, gh auth |

**Dropped vs old monolithic setup.sh:** Node.js 24, bun, Codex CLI. Add manually if needed.

## RunPod Architecture

```
/home/kit/              ← local FS (ephemeral — recreated by create-user.sh on restart)
├── .ssh/               ← local FS
├── code/               → /workspace/code    (persists; dotfiles-chezmoi clone)
├── .claude/            → /workspace/.claude (persists)
├── .local/             → /workspace/.local  (persists)
└── .config/            → /workspace/.config (persists; chezmoi config lives here)
```

## Configuration

Override via env vars:

| Variable | Default | Description |
|----------|---------|-------------|
| `USERNAME` | `kit` | Non-root username |
| `GITHUB_USER` | `K-Kit` | GitHub username (for SSH key import) |
| `DOTFILES_REPO` | `https://github.com/K-Kit/dotfiles-chezmoi.git` | Dotfiles repo (source + content) |
| `DOTFILES` / `CHEZMOI_DIR` | `$USER_HOME/code/dotfiles-chezmoi` | Clone path |
| `DOTFILES_BRANCH` | (required in setup.sh) | Branch to clone |
| `BWS_TOKEN` | (unset) | BWS access token (non-interactive) |
| `TAILSCALE_AUTH_KEY` | (unset) | Tailscale auth key (non-interactive) |
| `INTERACTIVE` | `0` | Set `1` / pass `-i` to prompt for secrets |
| `GITHUB_AUTH` | `0` | Set `1` / pass `--github-auth` to auth gh inline |
| `CHEZMOI_PROFILE` | `cloud` (set by setup.sh) | chezmoi profile: personal/server/cloud/minimal |

### Non-interactive by default

`setup.sh` never blocks on a prompt — safe for `curl | bash` with no TTY.
Supply secrets via env (`BWS_TOKEN=…`, `TAILSCALE_AUTH_KEY=…`) or set them up after login.
Pass `-i` / `--interactive` to prompt on a box with a real terminal.
