{ pkgs, ... }:
let
  nlmingestor = "/home/nixos-server/Fun/Projects/nlm-ingestor";
in
{
  # systemd.services.nlmingestor-tika = {
  #   description = "systemd unit to run tika server";
  #   after = [ "network.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     User = "nixos-server";
  #     Group = "users";
  #     WorkingDirectory = nlmingestor;
  #     Environment = [
  #       "PATH=/home/nixos-server/.nix-profile/bin:/etc/profiles/per-user/nixos-server/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
  #     ];
  #     ExecStart = "${pkgs.jdk}/bin/java -jar ${nlmingestor}/jars/tika-server-standard-nlm-modified-2.9.2_v2.jar"; 
  #     StandardOutput = "journal";
  #     StandardError = "journal";
  #   };
  # };
  #
  # systemd.services.nlmingestor-ingestion-daemon = {
  #   description = "systemd unit to run ingestion daemon";
  #   after = [ "network.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     User = "nixos-server";
  #     Group = "users";
  #     WorkingDirectory = nlmingestor;
  #     Environment = [
  #       "PATH=/home/nixos-server/Fun/Projects/nlm-ingestor/.venv/bin" "LD_LIBRARY_PATH=${pkgs.libstdcxx5.out}/lib:${pkgs.stdenv.cc.cc.lib}/lib"
  #     ];
  #     ExecStart = "${nlmingestor}/.venv/bin/python -m nlm_ingestor.ingestion_daemon"; 
  #     StandardOutput = "journal";
  #     StandardError = "journal";
  #   };
  # };
}
