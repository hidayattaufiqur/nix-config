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

  # Advertise smolpanda as a tailnet exit node. Idempotent — just re-applies
  # the pref on every boot so it survives prefs resets. Enabling other nodes
  # to actually USE it requires the tailnet admin to approve the exit node
  # (or an ACL that allows exit node use).
  systemd.services.tailscale-exit-node = {
    description = "Advertise smolpanda as Tailscale exit node";
    wantedBy = [ "multi-user.target" ];
    after = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = "10s";
      ExecStart = "${pkgs.tailscale}/bin/tailscale set --advertise-exit-node";
    };
  };

  # opencode web UI (headless). Bound to loopback only — exposed over the
  # tailnet via `tailscale serve` (HTTPS, tailnet-only, ACL-gated). Raw API
  # must never be reachable on the tailnet without going through serve.
  systemd.services.opencode-web = {
    description = "opencode web UI";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "tailscaled.service" ];
    serviceConfig = {
      User = "smolpanda";
      Group = "users";
      WorkingDirectory = "/home/smolpanda";
      ExecStart = "${upkgs.opencode}/bin/opencode web --hostname 127.0.0.1 --port 4096";
      Restart = "on-failure";
      RestartSec = "3s";
      # Memory caps added 2026-08-08: steady state ~800M but peaked at 3G
      # (Bun runtime + in-heap session state; no swap on this box). Soft
      # reclaim above 2G; hard kill at 2.5G — service auto-restarts, session
      # state persists in ~/.local/share/opencode DB. Bumped 1G/1.5G -> 2G/2.5G
      # after live usage approached the old hard cap.
      MemoryHigh = "2048M";
      MemoryMax = "2560M";
    };
  };

  # opencode2 (v2 beta) server API. v2 dropped the `web` subcommand — the
  # browser surface is the hosted Console (console.opencode.ai) + Electron
  # desktop app, which pair with this local API server. Bound to loopback
  # only, exposed over the tailnet via tailscale serve (:4444). Unlike v1,
  # the v2 API REQUIRES basic auth: credentials come from
  # ~/.config/opencode2-server.env (OPENCODE_SERVER_USERNAME/PASSWORD,
  # mode 600, created by the agent during install). Mirrors opencode-web's
  # unit shape and memory caps; sessions persist in ~/.local/share/opencode.
  systemd.services.opencode2-web = {
    description = "opencode2 v2 beta server API";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "tailscaled.service" ];
    serviceConfig = {
      User = "smolpanda";
      Group = "users";
      WorkingDirectory = "/home/smolpanda";
      EnvironmentFile = "/home/smolpanda/.config/opencode2-server.env";
      ExecStart = "/home/smolpanda/.bun/bin/opencode2 serve --hostname 127.0.0.1 --port 4097";
      Restart = "on-failure";
      RestartSec = "3s";
      # Same caps as opencode-web: soft reclaim above 2G, hard kill at 2.5G.
      # Native binary should run far lighter than v1's Bun runtime; caps are
      # a safety backstop (no swap on this box).
      MemoryHigh = "2048M";
      MemoryMax = "2560M";
    };
  };

  # Expose opencode-web over the tailnet only: tailscale serve gives HTTPS on
  # https://smolpanda.<tailnet>.ts.net:4443, reachable solely via tailnet
  # (firewall trusts tailscale0) and gated by tailnet ACLs. serve config is
  # persisted by tailscaled, so this unit mainly establishes it (idempotent).
  # HTTP on :8443 works on all plans (WireGuard already encrypts the tunnel);
  # HTTPS :4443 activates once the account plan supports TLS certs. The v2
  # beta API is served alongside on :4444 -> 127.0.0.1:4097 (separate port,
  # separate mount — avoids the "multiple types for a single mount point"
  # conflict).
  systemd.services.tailscale-serve = {
    description = "Serve opencode-web + opencode2 over the tailnet via tailscale serve";
    wantedBy = [ "multi-user.target" ];
    after = [ "tailscaled.service" "opencode-web.service" "opencode2-web.service" ];
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = "10s";
      # Idempotent: reset first so a stale mount can't cause
      # "cannot serve multiple types for a single mount point" (seen when
      # --http and --https target the same mount '/'), which aborted the
      # whole nixos-rebuild switch. HTTPS :4443/:4444 only — the :8443 HTTP
      # workaround was retired once TLS certs started working. Serve HTTPS
      # is tailnet-only by default (funnel is the opt-in for public).
      #
      # ExecStart is a LIST on purpose: systemd does NOT shell-interpret
      # `&&` in a single ExecStart string (the tokens are passed as literal
      # argv to one process), so a one-line `reset && serve --bg ...` chain
      # silently degraded to reset-only and the serve mounts were never
      # (re)applied by the unit — they were riding on persisted tailscaled
      # state. Type=oneshot runs ExecStart entries sequentially, so three
      # entries gives reset-then-serve-then-serve semantics.
      ExecStart = [
        "${pkgs.tailscale}/bin/tailscale serve reset"
        "${pkgs.tailscale}/bin/tailscale serve --bg --https=4443 http://127.0.0.1:4096"
        "${pkgs.tailscale}/bin/tailscale serve --bg --https=4444 http://127.0.0.1:4097"
      ];
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
