FROM ubuntu:24.04

ARG SPACE_USER=space
ARG SPACE_UID=1000
ARG SPACE_GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV SPACE_USER=${SPACE_USER}
ENV HOME=/home/${SPACE_USER}
ENV PATH=/home/${SPACE_USER}/.local/bin:/home/${SPACE_USER}/.npm-global/bin:/home/${SPACE_USER}/.bun/bin:/home/${SPACE_USER}/.local/share/mise/shims:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        gnupg \
        locales \
        python3 \
        sudo \
        tini \
        zsh \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid "${SPACE_GID}" "${SPACE_USER}" \
    && useradd --uid "${SPACE_UID}" --gid "${SPACE_GID}" --create-home --shell /usr/bin/zsh "${SPACE_USER}" \
    && echo "${SPACE_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${SPACE_USER}" \
    && chmod 0440 "/etc/sudoers.d/${SPACE_USER}"

WORKDIR /home/${SPACE_USER}/dotfiles
COPY --chown=${SPACE_UID}:${SPACE_GID} . .

USER ${SPACE_USER}
RUN zsh ./install.sh --profile=personal --non-interactive --no-apps --no-cleanup --no-create-user \
    && zsh ./deploy.sh --minimal --shell --tmux --vim --claude --codex --opencode --git-config --pkg-configs

USER root
COPY --chown=root:root runpod/space-entrypoint.sh /usr/local/bin/space-entrypoint
RUN chmod 0755 /usr/local/bin/space-entrypoint \
    && mkdir -p /workspace \
    && chown "${SPACE_UID}:${SPACE_GID}" /workspace

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/space-entrypoint"]
CMD ["zsh", "-l"]
