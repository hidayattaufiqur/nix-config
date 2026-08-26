{ pkgs, upkgs, ... }:

let
  adminKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOomYBKxrymgfIO1KFLc5POYxUcfO/P58ywRWJ2EwuVV nixos@nixos"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFl+CaHy7I2ix+tLbvSkBHnvRuCI2Tyma+tmpBUcpTjt hidayattaufiqur@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMoOWiNt2HdzK/2tNy0XP72ugiiYMqRtHkj3gc2rSivL hidayattaufiqur@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMN+6euukSpWncbYN+wczXPi+frMcp2osbEg0zi2VUf2"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINPL16Sma3ichRfxFlGtFAu7Y4uKQcRzQIo4G8N4YHKQ box@Box"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEBNBlgk6xkzE6ftX1+D0Fuquw6jO0CDyVipKMVe5TNQ pixel8-termux"
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

  # zram swap (added 2026-08-11): in-RAM compressed swap so opencode-web's
  # 2.16 GiB memory peaks spill into zram instead of thrashing the MemoryHigh
  # soft cap. No disk swap exists on this box. Size pinned to exactly 2 GiB:
  # zram-generator computes min(50% of ram, memoryMax) — memoryMax wins here.
  # zstd = default algorithm, good ratio + speed. Declarative, survives reboot.
  # NOTE: option is TOP-LEVEL `zramSwap` in nixos-25.11 (renamed from
  # services.zramSwap; the services.* path no longer exists in this nixpkgs).
  zramSwap = {
    enable = true;
    memoryMax = 2147483648; # 2 GiB in bytes — explicit, not % of RAM
    algorithm = "zstd";
  };

  # opencode v1 web UI service removed 2026-08-12 (t_5556f158): opencode 2.0
  # (opencode2-web below) serves every client surface (phone web, desktop web,
  # desktop app) against the shared v2 server on :4444. Dropping the v1 web
  # unit frees its ~1.8 GiB cgroup (Bun runtime + in-heap session state).
  # v1 CLI binary stays installed (hermes.nix extraPackages -> upkgs.opencode)
  # for the mastermind's one-shot runs; session history persists in
  # ~/.local/share/opencode/opencode-stable.db (untouched by this removal).
  # Re-enable by restoring the unit + :4443 mount if v1 history is ever needed.

  # opencode2 (v2 beta) server API — DISABLED 2026-08-26 (OOM declutter, user
  # decision). Nobody connects to :4097 (ss: no sockets), the TUI runs as its
  # own `opencode` process (not via this server), and the unit OOM-killed
  # (9/KILL) on 2026-08-24. Sessions persist in ~/.local/share/opencode —
  # untouched. Re-enable by restoring this block if the hosted Console or
  # desktop app needs the local API again.

  # Memory cap for opencode sessions launched ad-hoc (tmux/hermes-work, e.g.
  # `opencode -s ses_...`). Sessions are bun processes that balloon to 1GB+ RSS
  # and 18GB VmSize, OOMing the 8GB box (seen 2026-08-26 15:43 — two
  # .opencode-wrapp killed, took systemd+dbus with them). Launch sessions via
  # `systemd-run --scope --unit=opencode-session@<n> ...` to inherit the cap.
  systemd.slices.opencode = {
    wantedBy = [ "multi-user.target" ];
  };
  systemd.services."opencode-session@" = {
    description = "opencode session (memory-capped)";
    serviceConfig = {
      Slice = "opencode.slice";
      # Soft reclaim above 1G, hard kill at 1.5G — matches the opencode2-web
      # pattern. Sessions are transient work; killing one beats killing systemd.
      MemoryHigh = "1G";
      MemoryMax = "1536M";
      TasksMax = 512;
      OOMPolicy = "kill";
    };
  };

  # opencode2 tailnet serve — DISABLED with opencode2-web 2026-08-26 (OOM
  # declutter). No :4444 mount while the API is down. Re-enable with the unit.
  # systemd.services.tailscale-serve = {
  #   description = "Serve opencode2 over the tailnet via tailscale serve";
  #   wantedBy = [ "multi-user.target" ];
  #   after = [ "tailscaled.service" "opencode2-web.service" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     Restart = "on-failure";
  #     RestartSec = "10s";
  #     ExecStart = [
  #       "${pkgs.tailscale}/bin/tailscale serve reset"
  #       "${pkgs.tailscale}/bin/tailscale serve --bg --https=4444 http://127.0.0.1:4097"
  #     ];
  #   };
  # };

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
