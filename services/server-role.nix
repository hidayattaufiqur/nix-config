{ lib, ... }:
{
  options.services.server-role = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "nixos-server";
      description = "User that runs the server application workloads.";
    };
    homeDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/nixos-server";
      description = "Home directory of the server workloads user.";
    };
  };
}
