{ config, lib, ... }:
{
  # Lock down exposed ports for this host.
  networking.firewall = {
    enable = true;

    # Trust Tailscale interface for tailnet access only.
    trustedInterfaces = [ "tailscale0" ];

    # Only expose SSH, HTTP, HTTPS on the public interface.
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ config.services.tailscale.port ];

    # Needed with Docker/Tailscale to avoid asymmetric route drops.
    checkReversePath = "loose";
  };
}

