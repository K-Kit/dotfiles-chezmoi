from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_agentation_is_shared_across_agents() -> None:
    source = json.loads((ROOT / "config" / "mcp-servers.json").read_text())
    assert source["mcpServers"]["agentation"] == {
        "command": "npx",
        "args": ["-y", "agentation-mcp", "server"],
    }

    skill = (ROOT / "claude" / "skills" / "agentation" / "SKILL.md").read_text()
    assert "name: agentation" in skill
    assert "NODE_ENV" in skill
    assert "agentation-mcp doctor" in skill


def test_opencode_has_managed_config() -> None:
    config = json.loads(
        (ROOT / "config" / "opencode" / "opencode.json").read_text()
    )
    assert config["$schema"] == "https://opencode.ai/config.json"
    assert config["share"] == "disabled"
    assert config["mcp"]["agentation"]["command"] == [
        "npx",
        "-y",
        "agentation-mcp",
        "server",
    ]
    assert config["mcp"]["agentation"]["enabled"] is False

    deploy = (ROOT / "deploy.sh").read_text()
    assert 'OPENCODE_CONFIG_DIR="$HOME/.config/opencode"' in deploy
    assert 'ln -s "$DOT_DIR/config/opencode/opencode.json"' in deploy


def test_space_image_supports_workspace_and_dind_modes() -> None:
    dockerfile = (ROOT / "runpod" / "space.Dockerfile").read_text()
    entrypoint = (ROOT / "runpod" / "space-entrypoint.sh").read_text()
    compose = (ROOT / "runpod" / "compose.yml").read_text()

    assert "FROM ubuntu:24.04" in dockerfile
    assert "install.sh --profile=personal" in dockerfile
    assert 'SPACE_DOCKER_MODE="${SPACE_DOCKER_MODE:-socket}"' in entrypoint
    assert "exec dockerd" not in entrypoint
    assert "dockerd" in entrypoint
    assert "workspace:" in compose
    assert "/var/run/docker.sock:/var/run/docker.sock" in compose
    assert "dind:" in compose
    assert "privileged: true" in compose
    assert "SPACE_DOCKER_MODE: dind" in compose


def test_space_image_has_ci_build_workflow() -> None:
    workflow = (ROOT / ".github" / "workflows" / "space-image.yml").read_text()
    assert "docker/build-push-action@" in workflow
    assert "push: false" in workflow
    assert "runpod/space.Dockerfile" in workflow


def test_help_lists_new_components() -> None:
    install_help = subprocess.run(
        ["zsh", str(ROOT / "install.sh"), "--help"],
        text=True,
        capture_output=True,
        check=True,
    ).stdout
    deploy_help = subprocess.run(
        ["zsh", str(ROOT / "deploy.sh"), "--help"],
        text=True,
        capture_output=True,
        check=True,
    ).stdout

    assert "--secrets-cli" in install_help
    assert "--opencode" in deploy_help


def test_secrets_cli_install_is_serial() -> None:
    install = (ROOT / "install.sh").read_text()
    block = install.split(
        "# ─── Password and Secrets CLIs", 1
    )[1].split("# ─── ZSH", 1)[0]
    assert "run_parallel" not in block
    assert block.index("install_proton_pass_cli") < block.index("install_fnox")
    assert block.index("install_fnox") < block.index("install_1password_cli")
