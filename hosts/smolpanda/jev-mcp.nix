{ jev-mcp, ... }:
let
  jevPkg = jev-mcp.packages.x86_64-linux.default;
in
{
  environment.systemPackages = [ jevPkg ];

  # jev is an *evaluator*, not a chat model: POST /v1/chat/completions with
  # orvix/jev hard-fails with 400 and points at /v1/evaluate, and CommandCode's
  # typesafe/jev only answers on /systemone. So it can never be a providers.*
  # entry. It is wired as a stdio MCP tool instead.
  #
  # Two evaluator legs, selected by JEV_BACKEND:
  #   auto (default) -> CommandCode first, Orvix second (fallback on 402/5xx)
  #   commandcode    -> CommandCode only
  #   orvix          -> Orvix only
  #
  # Tokens are ${VAR} placeholders (same idiom as NOTION_TOKEN in hermes.nix):
  # Hermes resolves them at server start from the profile's secret scope / .env,
  # so neither key lands in the nix store.
  #
  # 2026-11-01: the Orvix leg was out of credits (HTTP 402) and the
  # COMMANDCODE_API_KEY in $HERMES_HOME/.env was stale (401 everywhere), which
  # left jev_evaluate returning upstream_error. CommandCode auth also had to
  # move to x-api-key — it rejects `Authorization: Bearer` with 401. The binary
  # now owns both legs and the fallback, so no external workaround is needed.
  services.hermes-agent.mcpServers.jev = {
    command = "${jevPkg}/bin/jev-mcp";
    args = [ ]; # stdio, no args needed
    env = {
      # Credentials — resolved by Hermes from the profile secret scope / .env.
      ORVIX_TOKEN = "\${ORVIX_TOKEN}";
      COMMANDCODE_API_KEY = "\${COMMANDCODE_API_KEY}";
      # Optional overrides (defaults live in the binary):
      JEV_BACKEND = "auto";
      # ORVIX_BASE_URL          = "https://api.orvix.id/v1";
      # JEV_ORVIX_MODEL         = "orvix/jev";
      # COMMANDCODE_BASE_URL    = "https://api.commandcode.ai/provider/v1";
      # JEV_COMMANDCODE_MODEL   = "typesafe/jev";
    };
  };
}
