{ config, lib, pkgs, ... }:

# 9Router v0.5.119. v0.5.119 has a real git tag, so the build checks out the tag
# rather than a raw SHA. 9router-build.service builds it; 9router.service runs it
# with the persistent /var/lib/9router/data bind.
#
# Both behavioural source patches are now gone, so a version bump is close to a
# string change (see the one remaining edit — the version stamp — in buildScript):
#  - AgentRouter header-spoof plugin: retired 2026-11-16, provider unused (its
#    connection is inactive and no combo leg references it). The old 193-line
#    overlay replaced upstream's custom-server.js wholesale, so every bump
#    silently reverted upstream changes to that file.
#  - combo-400-fallthrough: upstream adopted it. v0.5.119's
#    open-sse/services/accountFallback.js:69-71 returns
#    { shouldFallback: false, cooldownMs: 0, requestScoped: true } for unmatched
#    4xx, and combo.js:580-600 advances to the next member on requestScoped with
#    no account cooldown, returning the first request-scoped failure only after
#    every member rejected the request. 9router-combo-fallback-check.mjs is kept
#    as a post-build guard on that upstream behaviour.
#
# SCHEMA_VERSION is still 2 at v0.5.119, so the SQLite file needs no migration;
# take a backup before switching anyway.
# Use the reachable CN package mirrors explicitly during image build.

let
  # Behavioural post-build check: upstream's own requestScoped combo advance, the
  # behaviour our deleted combo-400 patch used to provide. Keeps the drop honest —
  # if a future bump regresses it, the build fails instead of silently shipping.
  comboCheck = ./9router-combo-fallback-check.mjs;
  buildScript = pkgs.writeShellScriptBin "build-9router" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    VERSION="v0.5.119"
    # Image tag carries the only remaining local edit (the version stamp below):
    # the "already built, skip" guard keys on the tag, so a content change needs
    # a new tag or the stale image is silently reused.
    IMAGE_VERSION="v0.5.119-verstamp"
    # Real git tag (commit 1855aa44), matching npm gitHead for 0.5.119.
    REF="refs/tags/v0.5.119"
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
    git fetch -q --depth 1 origin "$REF"
    git checkout -q FETCH_HEAD

    # Upstream's tag bumps cli/package.json to 0.5.119 but leaves root package.json
    # at 0.5.116, and /api/version answers with pkg.version — so a pristine v0.5.119
    # tag advertises itself as 0.5.116. Stamp the pinned version (derived from
    # $VERSION, so a bump needs no edit here). Fails closed if the field is gone.
    PLAIN_VERSION=''${VERSION#v}
    ${pkgs.gnused}/bin/sed -i -E "0,/^  \"version\": \"[0-9.]+\",\$/s//  \"version\": \"$PLAIN_VERSION\",/" "$SRC/repo/package.json"
    grep -q "\"version\": \"$PLAIN_VERSION\"" "$SRC/repo/package.json" || {
      echo "FAIL: could not stamp root package.json to $PLAIN_VERSION"
      exit 1
    }

    # Build image from upstream Dockerfile
    ${pkgs.docker}/bin/docker build \
      --build-arg ALPINE_MIRROR=mirrors.aliyun.com \
      --build-arg NPM_REGISTRY=https://registry.npmmirror.com \
      --build-arg APP_VERSION="$VERSION" \
      -t "$IMAGE" "$SRC/repo"

    # Assert against the RUNTIME artifact, inside the image: a model-scoped 400 must
    # advance to the next combo leg (upstream requestScoped behaviour, which replaced
    # our local patch). Drop the tag on failure so the "already exists, skip" guard
    # on the next run cannot serve a regressed image.
    if ! ${pkgs.docker}/bin/docker run --rm --entrypoint sh "$IMAGE" \
         -c 'test -f /app/custom-server.js'; then
      echo "FAIL: custom-server.js absent from the built image"
      ${pkgs.docker}/bin/docker rmi -f "$IMAGE" >/dev/null 2>&1 || true
      exit 1
    fi
    if ! ${pkgs.docker}/bin/docker run --rm -i --entrypoint node "$IMAGE" \
         --input-type=module - < "${comboCheck}"; then
      echo "FAIL: combo requestScoped fallthrough check failed on the built image"
      ${pkgs.docker}/bin/docker rmi -f "$IMAGE" >/dev/null 2>&1 || true
      exit 1
    fi
    # /api/version answers with package.json's version, so assert the stamp survived
    # into the image the container runs. Drop the tag so the "already exists, skip"
    # guard cannot serve an image that reports the wrong version.
    if ! ${pkgs.docker}/bin/docker run --rm --entrypoint sh "$IMAGE" \
         -c 'grep -q "\"version\": \"0.5.119\"" /app/package.json'; then
      echo "FAIL: in-image package.json does not report 0.5.119 (/api/version would lie)"
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

  # Build 9router v0.5.119 image from source (runs once, cached in nix store path)
  systemd.services."9router-build" = {
    description = "Build 9router v0.5.119 from source";
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
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name 9router --network host --env INITIAL_PASSWORD -v /var/lib/9router/data:/app/data 9router-local:v0.5.119-verstamp";
      ExecStop = "-${pkgs.docker}/bin/docker stop 9router";
      Restart = "always";
      RestartSec = 10;
    };
  };
}
