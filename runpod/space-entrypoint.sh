#!/usr/bin/env bash
set -euo pipefail

SPACE_DOCKER_MODE="${SPACE_DOCKER_MODE:-socket}"
SPACE_USER="${SPACE_USER:-space}"
SPACE_HOME="$(getent passwd "$SPACE_USER" | cut -d: -f6)"

add_socket_group() {
    [[ -S /var/run/docker.sock ]] || return 0

    local socket_gid socket_group
    socket_gid="$(stat -c '%g' /var/run/docker.sock)"
    socket_group="$(getent group "$socket_gid" | cut -d: -f1 || true)"
    if [[ -z "$socket_group" ]]; then
        socket_group="space-docker"
        groupadd --gid "$socket_gid" "$socket_group"
    fi
    usermod -aG "$socket_group" "$SPACE_USER"
}

start_dind() {
    mkdir -p /var/lib/docker /var/run
    dockerd --host=unix:///var/run/docker.sock >/tmp/dockerd.log 2>&1 &
    local daemon_pid=$!

    local attempt
    for ((attempt = 0; attempt < 60; attempt++)); do
        if docker info >/dev/null 2>&1; then
            return 0
        fi
        if ! kill -0 "$daemon_pid" 2>/dev/null; then
            cat /tmp/dockerd.log >&2
            return 1
        fi
        sleep 1
    done

    cat /tmp/dockerd.log >&2
    echo "Docker daemon did not become ready" >&2
    return 1
}

case "$SPACE_DOCKER_MODE" in
    socket)
        add_socket_group
        ;;
    dind)
        start_dind
        usermod -aG docker "$SPACE_USER"
        ;;
    none)
        ;;
    *)
        echo "Unknown SPACE_DOCKER_MODE: $SPACE_DOCKER_MODE (expected socket, dind, or none)" >&2
        exit 64
        ;;
esac

exec sudo --preserve-env=PATH,TERM,COLORTERM -Hu "$SPACE_USER" \
    env HOME="$SPACE_HOME" "$@"
