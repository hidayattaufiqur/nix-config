{ config, pkgs, ... }:
let
  role = config.services.server-role;
  repo = "${role.homeDir}/Fun/Projects/fno-interactor";
  deployDir = "/var/lib/nginx/fno";
  deployTrigger = "${role.homeDir}/.hermes/fno-deploy-trigger";
in
{
  # Static production site deploy dir. Owned by the app user so the fno-deploy
  # oneshot (below) can write it; world-readable so nginx (user nginx) can
  # serve it. Created declaratively at every switch.
  systemd.tmpfiles.rules = [
    "d ${deployDir} 0755 ${role.user} users -"
  ];

  # The public site is the production STATIC build served by nginx from
  # ${deployDir}. The vite dev server below is LOCAL DEVELOPMENT ONLY:
  #   - bound to 127.0.0.1 (no public surface, no HMR/ws proxy in nginx)
  #   - the CVE-2026-39363 surface was the public vite ws; it is gone.
  # Rebuild + redeploy path (agent or human):
  #   touch ${deployTrigger}
  # fires fno-deploy.service: npm run build && rsync -> ${deployDir}.
  systemd.services.fno-interactor = {
    description = "FNO Interactor dev server (localhost only)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    # The agent cannot `systemctl restart` this unit (polkit-denied), so the
    # root hermes-rebuild switch is the restart path. Restart whenever the
    # project's lockfile changes between switches (npm installs), so
    # dependency updates (e.g. vite CVEs) take effect on the next rebuild.
    restartTriggers = [
      "${repo}/package-lock.json"
    ];

    serviceConfig = {
      User = role.user;
      Group = "users";
      WorkingDirectory = repo;
      Environment = [
        "PATH=${pkgs.nodejs}/bin:${role.homeDir}/.nix-profile/bin:/etc/profiles/per-user/${role.user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
      ];
      ExecStart = ''
        ${pkgs.nodejs}/bin/npm run dev -- --port 5000 --host 127.0.0.1
      '';
      # Restart = "on-failure";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Deploy trigger: touch ${deployTrigger} to rebuild + publish the static
  # site. Runs as the app user OUTSIDE the agent sandbox (systemd unit, not a
  # hermes child), so it can write ${deployDir} which the sandbox cannot.
  systemd.paths.fno-deploy = {
    description = "Watch for the fno-interactor deploy trigger file";
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathExists = deployTrigger;
  };

  systemd.services.fno-deploy = {
    description = "Build and deploy the fno-interactor static site";
    serviceConfig = {
      Type = "oneshot";
      User = role.user;
      Group = "users";
      WorkingDirectory = repo;
      Environment = [
        "PATH=${pkgs.nodejs}/bin:${role.homeDir}/.nix-profile/bin:/etc/profiles/per-user/${role.user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
      ];
      # First ExecStartPre deletes the trigger so each touch fires exactly once.
      ExecStartPre = [
        "${pkgs.coreutils}/bin/rm -f ${deployTrigger}"
      ];
      ExecStart = [
        "${pkgs.nodejs}/bin/npm run build"
        "${pkgs.rsync}/bin/rsync -a --delete ${repo}/build/ ${deployDir}/"
        "${pkgs.coreutils}/bin/chmod -R a+rX ${deployDir}"
      ];
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
