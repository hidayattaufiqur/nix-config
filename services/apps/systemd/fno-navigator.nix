{ config, pkgs, ... }:
let
  role = config.services.server-role;
  repo = "${role.homeDir}/Fun/Projects/fno-navigator";
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
  systemd.services.fno-navigator = {
    description = "FnO Navigator dev server (localhost only)";
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
    description = "Watch for the fno-navigator deploy trigger file";
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathExists = deployTrigger;
  };

  systemd.services.fno-deploy = {
    description = "Build and deploy the fno-navigator static site";
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

  # Auto-deploy: poll origin/main and publish when it moves.
  # Replaces the manual `touch ${deployTrigger}` step for the normal merge
  # flow. Deliberately NOT a GitHub Action: the site builds and serves on this
  # host, so a runner would have to execute public-repo code here as the app
  # user, or hold an SSH key to this box. Polling costs no new credentials.
  # The manual trigger above still works and is still the path for deploying a
  # working-tree state that has not been pushed.
  systemd.services.fno-auto-deploy = {
    description = "Auto-deploy fno-navigator when origin/main moves";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = role.user;
      Group = "users";
      WorkingDirectory = repo;
      Environment = [
        "PATH=${pkgs.nodejs}/bin:${pkgs.git}/bin:${pkgs.rsync}/bin:${role.homeDir}/.nix-profile/bin:/etc/profiles/per-user/${role.user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/bin"
        "HOME=${role.homeDir}"
      ];
      ExecStart = toString (pkgs.writeShellScript "fno-auto-deploy" ''
        set -euo pipefail
        cd ${repo}

        state=${role.homeDir}/.hermes/fno-auto-deploy.state

        # Only ever act on main. A feature branch here would publish unreviewed
        # code — the deploy trap this repo has hit three times.
        branch=$(git rev-parse --abbrev-ref HEAD)
        if [ "$branch" != "main" ]; then
          echo "skip: on '$branch', not main"; exit 0
        fi

        # A dirty tree means uncommitted work (often another agent's). Never
        # deploy or discard it.
        if [ -n "$(git status --porcelain)" ]; then
          echo "skip: working tree dirty"; exit 0
        fi

        git fetch origin main --quiet
        local_sha=$(git rev-parse HEAD)
        remote_sha=$(git rev-parse origin/main)

        if [ "$local_sha" = "$remote_sha" ]; then
          echo "up to date at $local_sha"; exit 0
        fi

        # A commit that failed to build before must not be retried forever.
        if [ -f "$state" ] && [ "$(cat "$state")" = "$remote_sha" ]; then
          echo "skip: $remote_sha already failed to build; waiting for a new commit"
          exit 0
        fi

        # Fast-forward only. Never merge, never rebase — a conflict here means
        # a human should look, not that the timer should improvise.
        git merge --ff-only origin/main

        if ! npm run build; then
          echo "$remote_sha" > "$state"
          git reset --hard "$local_sha"
          echo "BUILD FAILED for $remote_sha — rolled back to $local_sha"
          exit 1
        fi

        rm -f "$state"
        rsync -a --delete ${repo}/build/ ${deployDir}/
        chmod -R a+rX ${deployDir}
        echo "deployed $(git rev-parse HEAD)"
      '');
    };
  };

  systemd.timers.fno-auto-deploy = {
    description = "Poll origin/main for fno-navigator every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      Persistent = true;
      Unit = "fno-auto-deploy.service";
    };
  };
}
