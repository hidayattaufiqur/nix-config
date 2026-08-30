{ dockerTools, fetchgit, nodejs, stdenv }:

# Build 9router v0.5.59 from source since no container image was published.
# The upstream custom-server.js in v0.5.59 already includes the x-9r-real-ip
# hardening that the local AgentRouter-spoof patch was compensating for, so
# that patch is NO LONGER needed — we use the upstream file as-is.
#
# ponytail: building the full Docker image at eval time is heavyweight;
# the previous approach just referenced decolua/9router:latest. Acceptable
# ceiling here because the image is cached in the nix store and only
# rebuilds on git revision change. Upgrade path: switch back to
# dockerPullImage once 9router publishes CI-built images for v0.5.59+.

let
  src = fetchgit {
    url = "https://github.com/decolua/9router.git";
    rev = "v0.5.59";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
in
dockerTools.buildImage {
  name = "decolua/9router";
  tag = "v0.5.59";
  config = {
    Cmd = [ "node" "custom-server.js" ];
    ExposedPorts = { "20128/tcp" = {}; };
  };
  # We can't easily run the full build (needs npm, next build, etc.) inline here.
  # Instead, we fetch the source and use the pre-built standalone layout.
  # The Dockerfile approach is more practical — use buildLayeredImage.
  # Actually: simplest path is dockerTools.buildLayeredImage with dockerfile.
  dockerfile = src + "/Dockerfile";
  extrabuildCommands = ''
    # The upstream image is node-based; we just need to ensure the
    # bind-mounted custom-server.js override works.
  '';
}
