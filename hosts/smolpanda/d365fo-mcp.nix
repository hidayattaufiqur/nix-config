{ d365fo-mcp, ... }:
let
  d365foPkg = d365fo-mcp.packages.x86_64-linux.default;
  # Production index outside git/tmpfs: survives reboot, not in repo, read-only at serve time
  d365foIndex = "/home/smolpanda/.local/share/d365fo-mcp/index";
in
{
  environment.systemPackages = [ d365foPkg ];

  # Ensure index parent exists for the operator to populate; the index itself
  # is built externally via `d365fo-mcp catalog` (see docs/operations.md).
  systemd.tmpfiles.rules = [
    "d /home/smolpanda/.local/share/d365fo-mcp 0750 smolpanda users - -"
    "d ${d365foIndex} 0750 smolpanda users - -"
  ];

  services.hermes-agent.mcpServers.d365fo = {
    command = "${d365foPkg}/bin/d365fo-mcp";
    args = [ "mcp" "--index" d365foIndex ];
  };
}
