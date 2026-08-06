{ pkgs, upkgs, ... }:

let
  adminKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFl+CaHy7I2ix+tLbvSkBHnvRuCI2Tyma+tmpBUcpTjt hidayattaufiqur@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMoOWiNt2HdzK/2tNy0XP72ugiiYMqRtHkj3gc2rSivL hidayattaufiqur@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMN+6euukSpWncbYN+wczXPi+frMcp2osbEg0zi2VUf2"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINPL16Sma3ichRfxFlGtFAu7Y4uKQcRzQIo4G8N4YHKQ box@Box"
  ];
in
{
  imports = [
    ../../services/ssh.nix
  ];

  services.tailscale.enable = true;

  # opencode web UI (headless), reachable via the tailnet (firewall trusts tailscale0).
  systemd.services.opencode-web = {
    description = "opencode web UI";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "tailscaled.service" ];
    serviceConfig = {
      User = "smolpanda";
      Group = "users";
      WorkingDirectory = "/home/smolpanda";
      ExecStart = "${upkgs.opencode}/bin/opencode web --hostname 0.0.0.0 --port 4096";
      Restart = "on-failure";
      RestartSec = "3s";
    };
  };

  networking = {
    hostName = "smolpanda";
    useDHCP = false;
    interfaces.ens3 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "103.74.5.153";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      address = "103.74.5.1";
      interface = "ens3";
    };
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  services.openssh.settings = {
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = adminKeys;

  users.users.smolpanda = {
    isNormalUser = true;
    description = "smolpanda administrator";
    extraGroups = [ "wheel" "systemd-journal" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = adminKeys;
  };

  security.sudo.wheelNeedsPassword = false;
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    jq
    neovim
    python3
    tmux
    wget
  ];

  time.timeZone = "Asia/Jakarta";
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "25.11";
}
