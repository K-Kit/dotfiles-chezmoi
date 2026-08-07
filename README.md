# dotfiles-chezmoi

Chezmoi **source repository** for [K-Kit/dotfiles-ai](https://github.com/K-Kit/dotfiles-ai).

This repo holds the chezmoi source state (`home/` via `.chezmoiroot`), profiles, and `run_onchange` scripts. Config content (`config/`, `claude/`, `codex/`, `install.sh`, etc.) lives in **dotfiles-ai** and is cloned to `~/code/dotfiles-ai` on first apply.

## Two-repo layout

| Repo | Role |
|------|------|
| **dotfiles-chezmoi** (this repo) | chezmoi source: managed paths, profiles, apply scripts |
| **dotfiles-ai** | Content + installers: shell config, AI configs, packages |

Symlinks in `home/` point at `{{ .dot_dir }}/config/...` (default `~/code/dotfiles-ai`).

## Quickstart

```bash
# Install chezmoi
sh -c "$(curl -fsSL https://get.chezmoi.io)"

# Init + apply (clones dotfiles-ai automatically on first run)
CHEZMOI_PROFILE=personal chezmoi init --apply K-Kit/dotfiles-chezmoi

# From a local clone
git clone https://github.com/K-Kit/dotfiles-chezmoi.git ~/code/dotfiles-chezmoi
CHEZMOI_PROFILE=personal chezmoi --source ~/code/dotfiles-chezmoi init --apply
```

## Profiles

Set `CHEZMOI_PROFILE` to one of: `personal`, `server`, `cloud`, `minimal`.

Component flags: [`home/.chezmoidata/profiles.yaml`](home/.chezmoidata/profiles.yaml).

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `CHEZMOI_PROFILE` | `personal` | Profile name |
| `DOT_DIR` | `$CODE_DIR/dotfiles-ai` | Path to dotfiles-ai clone |
| `DOTFILES_REPO` | `https://github.com/K-Kit/dotfiles-ai.git` | Content repo URL |
| `DOTFILES_BRANCH` | `main` | Content repo branch |
| `CODE_DIR` | `~/code` | Base directory for clones |

## Cloud / RunPod

[`dotfiles-ai/scripts/cloud/setup.sh`](https://github.com/K-Kit/dotfiles-ai/blob/main/scripts/cloud/setup.sh) installs chezmoi, clones both repos, and runs `chezmoi apply` with `CHEZMOI_PROFILE=cloud`.

## Development

```bash
# Dry-run file deploy only (skip install scripts)
CHEZMOI_PROFILE=cloud CHEZMOI_NON_INTERACTIVE=1 \
  chezmoi --source "$PWD" apply --exclude scripts

# List managed targets
chezmoi --source "$PWD" managed
```

## Structure

```
dotfiles-chezmoi/
├── .chezmoiroot              → home
├── .chezmoi.toml.tmpl        # profile + dot_dir defaults
├── home/                     # chezmoi source state → ~/
│   ├── .chezmoidata/profiles.yaml
│   ├── .chezmoiscripts/      # run_once / run_onchange
│   └── dot_*, symlink_*      # managed dotfiles
└── scripts/lib.sh            # shared helpers (sources dotfiles-ai config.sh)
```
