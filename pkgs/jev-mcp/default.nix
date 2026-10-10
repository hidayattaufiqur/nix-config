{
  buildGoModule,
}:

# Zero external Go dependencies: JSON-RPC framing, HTTP and JSON are all stdlib.
# There is deliberately no go.sum and no vendor/ directory.
# `vendorHash = null` tells buildGoModule there is nothing to fetch or vendor.
# If a dependency is ever added, replace it with `lib.fakeHash` once to read
# the real hash out of the build error.
buildGoModule {
  pname = "jev-mcp";
  version = "0.1.0";

  src = ./.;

  vendorHash = null;
  ldflags = [ "-s" "-w" ];

  meta = {
    description = "Stdio MCP server exposing the Orvix jev evaluator as the jev_evaluate tool";
    mainProgram = "jev-mcp";
  };
}
