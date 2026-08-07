# Chezmoi (single repo)

This repository is both the **chezmoi source** (`home/` via `.chezmoiroot`) and the **content** tree (`config/`, `claude/`, `install.sh`, etc.).

`DOT_DIR` defaults to the chezmoi working tree (this checkout).

## Apply dotfiles

```bash
CHEZMOI_PROFILE=personal chezmoi --source "$PWD" apply

# Or via deprecated wrappers (forward to chezmoi)
./deploy.sh --profile=personal
./install.sh --profile=personal
```

## Env

| Variable | Default |
|----------|---------|
| `CHEZMOI_SOURCE` | this checkout (`$DOT_DIR`) when `.chezmoiroot` is present |
| `CHEZMOI_REPO` | `https://github.com/K-Kit/dotfiles-chezmoi.git` |
| `DOT_DIR` | chezmoi working tree (set in `home/.chezmoi.toml.tmpl`) |
| `CHEZMOI_PROFILE` | `personal` / `server` / `cloud` / `minimal` |

Profiles: [`home/.chezmoidata/profiles.yaml`](../../home/.chezmoidata/profiles.yaml).
