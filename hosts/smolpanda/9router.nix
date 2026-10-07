{ config, lib, pkgs, ... }:

# 9Router v0.5.91 from source + AgentRouter header-spoof overlay.
# Latest upstream stable tag verified 2026-09-30; SQLite/data bind is preserved.
# 9router-build.service builds the pinned tag with the local AgentRouter overlay;
# 9router.service runs it with the persistent /var/lib/9router/data bind.
# The previous v0.5.69 image remains installed for rollback.
#
# ponytail: upstream custom-server.js is byte-identical between v0.5.69 and
# v0.5.91, so the overlay needs no rebase. The v0.5.91 DB diff contains no
# schema migration; stay on the same SQLite file and keep v0.5.69 as rollback.
# Use the reachable CN package mirrors explicitly during image build.

let
  # AgentRouter header-spoof patch — injects Claude Code / Copilot headers
  # when 9router proxies to agentrouter.org upstreams.
  overlayScript = ./9router-agentrouter-overlay.js;
  buildScript = pkgs.writeShellScriptBin "build-9router" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    TAG="v0.5.91"
    IMAGE="9router-local:$TAG"

    # Skip if image already built
    if ${pkgs.docker}/bin/docker image inspect "$IMAGE" >/dev/null 2>&1; then
      echo "9router-local:$TAG already exists, skipping build"
      exit 0
    fi

    SRC="/var/lib/9router/build-src"
    rm -rf "$SRC"
    mkdir -p "$SRC"

    git clone --depth 1 --branch "$TAG" \
      https://github.com/decolua/9router.git "$SRC/repo"

    # Overlay AgentRouter header-spoof patch into custom-server.js
    cp "${overlayScript}" "$SRC/repo/custom-server.js"

    # Build image from upstream Dockerfile
    ${pkgs.docker}/bin/docker build \
      --build-arg ALPINE_MIRROR=mirrors.aliyun.com \
      --build-arg NPM_REGISTRY=https://registry.npmmirror.com \
      --build-arg APP_VERSION="$TAG" \
      -t "$IMAGE" "$SRC/repo"

    rm -rf "$SRC"
    echo "9router build complete: $IMAGE"
  '';
in
{
  # Secret lives in secrets-extra.yaml (agent-editable, no root needed).
  sops.secrets."9router-initial-password" = {
    sopsFile = ../../secrets/secrets-extra.yaml;
  };
  sops.templates."9router.env" = {
    content = "INITIAL_PASSWORD=${config.sops.placeholder."9router-initial-password"}";
  };

  # Persistent data dir (survives container rm/run cycles).
  systemd.tmpfiles.rules = [
    "d /var/lib/9router/data 0755 root root -"
    "d /var/lib/9router/build-src 0755 root root -"
  ];

  # Build 9router v0.5.91 image from source (runs once, cached in nix store path)
  systemd.services."9router-build" = {
    description = "Build 9router v0.5.91 from source";
    after = [ "network.target" "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${buildScript}/bin/build-9router";
      EnvironmentFile = config.sops.templates."9router.env".path;
    };
  };

  systemd.services."9router" = {
    description = "9Router AI Model Router (Docker)";
    after = [ "network.target" "docker.service" "9router-build.service" ];
    requires = [ "docker.service" ];
    wants = [ "9router-build.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      EnvironmentFile = config.sops.templates."9router.env".path;
      ExecStartPre = "-${pkgs.docker}/bin/docker rm -f 9router";
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name 9router --network host --env INITIAL_PASSWORD -v /var/lib/9router/data:/app/data 9router-local:v0.5.91";
      ExecStop = "-${pkgs.docker}/bin/docker stop 9router";
      Restart = "always";
      RestartSec = 10;
    };
  };
}
