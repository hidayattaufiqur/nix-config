{ config, lib, pkgs, ... }:

# 9Router v0.5.99 + AgentRouter header-spoof overlay + combo-400-fallthrough patch.
# 0.5.99 has no git tag, so the build pins the npm-published commit ce4460ef.
# 9router-build.service builds that commit with the local AgentRouter overlay and
# the combo-400-fallthrough patch; 9router.service runs it with the persistent
# /var/lib/9router/data bind.
# Local image tags are versioned by patch content (v0.5.99 → v0.5.99-combo400):
# the build-service "image exists, skip" guard keys on the tag, so a new tag per
# patch keeps a stale unpatched image from being silently reused.
# The previous v0.5.99 image remains installed for rollback.
#
# ponytail: upstream custom-server.js is byte-identical between v0.5.91 (f01fb909)
# and the 0.5.99 commit ce4460ef (sha256 c3b4f23a…), so the overlay needs no rebase.
# The 0.5.91 -> 0.5.99 DB diff is additive only (apiKeys.accessRestricted/accessAllow,
# SCHEMA_VERSION 1 -> 2); syncSchemaFromTables() adds the columns on boot after a
# pre-change backup. Same SQLite file, v0.5.91 stays as rollback.
# Use the reachable CN package mirrors explicitly during image build.

let
  # AgentRouter header-spoof patch — injects Claude Code / Copilot headers
  # when 9router proxies to agentrouter.org upstreams.
  overlayScript = ./9router-agentrouter-overlay.js;
  # Combo fallthrough patch — a model-scoped 400 must advance to the next combo
  # leg instead of aborting the chain (card t_54fa8e8b). Applied to the checked
  # out source BEFORE `npm run build`, because the Next bundle is what the route
  # handlers actually load at runtime (.next/server/chunks/8910.js), not the
  # open-sse/*.js source that ships alongside it. Fails the build if upstream
  # refactors that block away.
  comboPatch = ./9router-combo-fallback-patch.mjs;
  buildScript = pkgs.writeShellScriptBin "build-9router" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    VERSION="v0.5.99"
    # Image tag carries the local patch revision: the "already built, skip"
    # guard below keys on the tag, so reusing the bare version tag after a
    # patch change would silently serve the UNPATCHED image.
    IMAGE_VERSION="v0.5.99-combo400"
    # npm gitHead of 0.5.99; no v0.5.99 tag exists, so pin the immutable commit.
    COMMIT="ce4460ef79382bfddb4aa5fc0ff9f3cb0d5f95a8"
    IMAGE="9router-local:$IMAGE_VERSION"

    # Skip if image already built
    if ${pkgs.docker}/bin/docker image inspect "$IMAGE" >/dev/null 2>&1; then
      echo "$IMAGE already exists, skipping build"
      exit 0
    fi

    SRC="/var/lib/9router/build-src"
    rm -rf "$SRC"
    mkdir -p "$SRC/repo"
    cd "$SRC/repo"
    git init -q .
    git remote add origin https://github.com/decolua/9router.git
    git fetch -q --depth 1 origin "$COMMIT"
    git checkout -q FETCH_HEAD

    # Overlay AgentRouter header-spoof patch into custom-server.js
    cp "${overlayScript}" "$SRC/repo/custom-server.js"

    # Combo fallthrough patch (pre-build: the Next bundle is the runtime artifact)
    ${pkgs.nodejs}/bin/node "${comboPatch}" "$SRC/repo/open-sse/services/combo.js"

    # Build image from upstream Dockerfile
    ${pkgs.docker}/bin/docker build \
      --build-arg ALPINE_MIRROR=mirrors.aliyun.com \
      --build-arg NPM_REGISTRY=https://registry.npmmirror.com \
      --build-arg APP_VERSION="$VERSION" \
      -t "$IMAGE" "$SRC/repo"

    # The patch script edits open-sse/services/combo.js, but the route handlers load
    # the Next bundle. Assert the patch reached the artifact that actually serves
    # traffic; on failure drop the tag so the "already exists, skip" guard on the
    # next run cannot serve an unpatched image.
    if ! ${pkgs.docker}/bin/docker run --rm --entrypoint sh "$IMAGE" \
         -c 'grep -rq "trying next (no account cooldown)" /app/.next'; then
      echo "FAIL: combo-400-fallthrough patch absent from the built .next bundle"
      ${pkgs.docker}/bin/docker rmi -f "$IMAGE" >/dev/null 2>&1 || true
      exit 1
    fi

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

  # Build 9router v0.5.99 image from source (runs once, cached in nix store path)
  systemd.services."9router-build" = {
    description = "Build 9router v0.5.99 from source";
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
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name 9router --network host --env INITIAL_PASSWORD -v /var/lib/9router/data:/app/data 9router-local:v0.5.99-combo400";
      ExecStop = "-${pkgs.docker}/bin/docker stop 9router";
      Restart = "always";
      RestartSec = 10;
    };
  };
}
