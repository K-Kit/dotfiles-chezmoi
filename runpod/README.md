# Dotfiles Space image

`space.Dockerfile` builds the complete personal Dotfiles profile in Ubuntu 24.04. It includes the AI CLIs, password/secrets CLIs, shared skills, OpenCode configuration, Docker Engine, Compose, and the normal terminal toolchain.

## Use the host Docker daemon

```bash
SPACE_WORKSPACE="$PWD" docker compose -f runpod/compose.yml run --rm workspace
```

This mounts `/var/run/docker.sock` and adds the container user to its numeric group at startup. The container can control the host daemon; only use this with trusted code.

## Use Docker-in-Docker

```bash
SPACE_WORKSPACE="$PWD" docker compose -f runpod/compose.yml --profile dind run --rm dind
```

The `dind` service is privileged and starts an isolated daemon backed by the `docker-data` volume. Use it when host-daemon access is undesirable or unavailable.

## Build only

```bash
docker build -f runpod/space.Dockerfile -t dotfiles-space:local .
```
