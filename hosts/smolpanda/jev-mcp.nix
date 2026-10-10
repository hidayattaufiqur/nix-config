{ jev-mcp, ... }:
let
  jevPkg = jev-mcp.packages.x86_64-linux.default;
in
{
  environment.systemPackages = [ jevPkg ];

  # jev (orvix/jev) is an *evaluator*, not a chat model: POST /v1/chat/completions
  # with orvix/jev hard-fails with 400 and points at /v1/evaluate — so it can never
  # be a providers.orvix entry. It is wired as a stdio MCP tool instead.
  #
  # The binary itself lives in ~/Fun/Projects/jev-mcp (flake input above); this
  # file only declares how the system uses it.
  #
  # ORVIX_TOKEN is left as a ${VAR} placeholder (same idiom as NOTION_TOKEN in
  # hermes.nix): Hermes resolves it at server start from the profile's secret
  # scope / .env, so the token never lands in the nix store.
  services.hermes-agent.mcpServers.jev = {
    command = "${jevPkg}/bin/jev-mcp";
    args = [ ]; # stdio, no args needed
    env = {
      ORVIX_TOKEN = "\${ORVIX_TOKEN}";
      # Optional overrides (defaults live in the binary):
      # ORVIX_BASE_URL = "https://api.orvix.id/v1";
      # JEV_MODEL      = "orvix/jev";   # orvix/jev is the only evaluator
    };
  };
}
